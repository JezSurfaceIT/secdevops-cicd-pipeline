# Data Management Strategy for Dev-to-Test Pipeline
## Database States & File API Testing

**Version:** 1.0  
**Date:** 2025-09-21  
**Author:** Winston - System Architect

---

## 📊 Overview

This document defines the data management strategy for the Oversight MVP across development and test environments, including:
- Three distinct database states (schema-only, framework-only, full)
- State switching mechanisms
- Known-good snapshots and rollback procedures
- File API testing capabilities

---

## 🗄️ Database State Management

### Three Database States

```mermaid
graph LR
    subgraph "Database States"
        S1[State 1: Schema Only<br/>Empty Tables]
        S2[State 2: Framework Data<br/>Reference Data Only]
        S3[State 3: Full Data<br/>Test Data + Framework]
    end
    
    subgraph "Use Cases"
        UC1[Unit Testing]
        UC2[Integration Testing]
        UC3[UAT/Load Testing]
    end
    
    S1 --> UC1
    S2 --> UC2
    S3 --> UC3
```

### State Definitions

| State | Name | Contents | Use Case | Size |
|-------|------|----------|----------|------|
| **1** | Schema Only | DDL only, empty tables | Unit tests, clean slate testing | ~10 MB |
| **2** | Framework Data | Reference data, lookups, configs | Integration testing | ~100 MB |
| **3** | Full Data | Framework + test transactions | UAT, performance testing | ~1 GB |

---

## 🔄 Database State Implementation

### PostgreSQL Backup Strategy

```bash
#!/bin/bash
# scripts/data/create-db-snapshots.sh

# Configuration
DB_HOST="postgres-oversight-test.postgres.database.azure.com"
DB_NAME="oversight_test"
DB_USER="oversight_admin"
BACKUP_DIR="/data/backups"

# Create State 1: Schema Only
create_schema_only_backup() {
    echo "Creating Schema-Only backup..."
    pg_dump \
        -h $DB_HOST \
        -U $DB_USER \
        -d $DB_NAME \
        --schema-only \
        --no-privileges \
        --no-owner \
        -f "$BACKUP_DIR/state1-schema-only.sql"
    
    # Compress and version
    gzip -c "$BACKUP_DIR/state1-schema-only.sql" > \
        "$BACKUP_DIR/state1-schema-only-$(date +%Y%m%d).sql.gz"
}

# Create State 2: Framework Data
create_framework_backup() {
    echo "Creating Framework Data backup..."
    
    # Tables to include in framework backup
    FRAMEWORK_TABLES=(
        "users"
        "roles"
        "permissions"
        "organizations"
        "frameworks"
        "framework_controls"
        "control_categories"
        "compliance_standards"
        "risk_matrices"
        "lookup_*"
    )
    
    # Build table list
    TABLE_LIST=""
    for table in "${FRAMEWORK_TABLES[@]}"; do
        TABLE_LIST="$TABLE_LIST -t $table"
    done
    
    pg_dump \
        -h $DB_HOST \
        -U $DB_USER \
        -d $DB_NAME \
        $TABLE_LIST \
        --data-only \
        -f "$BACKUP_DIR/state2-framework-data.sql"
    
    # Combine with schema
    cat "$BACKUP_DIR/state1-schema-only.sql" \
        "$BACKUP_DIR/state2-framework-data.sql" > \
        "$BACKUP_DIR/state2-framework-complete.sql"
    
    gzip -c "$BACKUP_DIR/state2-framework-complete.sql" > \
        "$BACKUP_DIR/state2-framework-$(date +%Y%m%d).sql.gz"
}

# Create State 3: Full Data
create_full_backup() {
    echo "Creating Full Data backup..."
    pg_dump \
        -h $DB_HOST \
        -U $DB_USER \
        -d $DB_NAME \
        --clean \
        --if-exists \
        -f "$BACKUP_DIR/state3-full-data.sql"
    
    gzip -c "$BACKUP_DIR/state3-full-data.sql" > \
        "$BACKUP_DIR/state3-full-$(date +%Y%m%d).sql.gz"
}

# Create all snapshots
create_all_snapshots() {
    create_schema_only_backup
    create_framework_backup
    create_full_backup
    
    # Store in Azure Blob Storage
    az storage blob upload-batch \
        --destination oversight-db-snapshots \
        --source "$BACKUP_DIR" \
        --pattern "*.gz"
}
```

### Database State Switcher

```bash
#!/bin/bash
# scripts/data/switch-db-state.sh

set -e

STATE="${1:-2}"  # Default to framework state
DB_HOST="postgres-oversight-test.postgres.database.azure.com"
DB_NAME="oversight_test"
DB_USER="oversight_admin"
BACKUP_DIR="/data/backups"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Switch database state
switch_state() {
    local state=$1
    
    log_warn "⚠️  This will replace all data in the test database!"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    # Create backup of current state
    log_info "Backing up current state..."
    pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME \
        -f "$BACKUP_DIR/previous-state-$(date +%Y%m%d%H%M%S).sql"
    
    case $state in
        1)
            log_info "Switching to State 1: Schema Only"
            restore_file="$BACKUP_DIR/state1-schema-only.sql"
            ;;
        2)
            log_info "Switching to State 2: Framework Data"
            restore_file="$BACKUP_DIR/state2-framework-complete.sql"
            ;;
        3)
            log_info "Switching to State 3: Full Data"
            restore_file="$BACKUP_DIR/state3-full-data.sql"
            ;;
        *)
            log_error "Invalid state: $state (use 1, 2, or 3)"
            exit 1
            ;;
    esac
    
    # Drop and recreate database
    log_info "Resetting database..."
    psql -h $DB_HOST -U $DB_USER -d postgres << EOF
DROP DATABASE IF EXISTS ${DB_NAME}_temp;
CREATE DATABASE ${DB_NAME}_temp;
EOF
    
    # Restore selected state
    log_info "Restoring state $state..."
    psql -h $DB_HOST -U $DB_USER -d ${DB_NAME}_temp < "$restore_file"
    
    # Swap databases
    log_info "Swapping databases..."
    psql -h $DB_HOST -U $DB_USER -d postgres << EOF
ALTER DATABASE $DB_NAME RENAME TO ${DB_NAME}_old;
ALTER DATABASE ${DB_NAME}_temp RENAME TO $DB_NAME;
DROP DATABASE ${DB_NAME}_old;
EOF
    
    log_info "✅ Successfully switched to state $state"
    
    # Verify
    verify_state $state
}

# Verify database state
verify_state() {
    local state=$1
    
    log_info "Verifying database state..."
    
    case $state in
        1)
            # Check for empty tables
            COUNT=$(psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c \
                "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;")
            if [ "$COUNT" -eq 0 ]; then
                log_info "✓ Schema only - all tables empty"
            else
                log_warn "Tables contain data: $COUNT rows"
            fi
            ;;
        2)
            # Check for framework data
            FRAMEWORK_COUNT=$(psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c \
                "SELECT COUNT(*) FROM frameworks;")
            INCIDENT_COUNT=$(psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c \
                "SELECT COUNT(*) FROM incidents;")
            
            if [ "$FRAMEWORK_COUNT" -gt 0 ] && [ "$INCIDENT_COUNT" -eq 0 ]; then
                log_info "✓ Framework data present, no test data"
            else
                log_warn "State verification warning"
            fi
            ;;
        3)
            # Check for full data
            TOTAL_COUNT=$(psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c \
                "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;")
            log_info "✓ Full data: $TOTAL_COUNT total rows"
            ;;
    esac
}

# Main execution
switch_state $STATE
```

---

## 📁 File API Management

### File Processing API Architecture

```mermaid
graph TB
    subgraph "File Input API"
        API[POST /api/files/process]
        VALIDATE[File Validation]
        QUEUE[Processing Queue]
        PROCESSOR[File Processor]
    end
    
    subgraph "Test File Management"
        STORAGE[Azure Blob Storage<br/>Test Files]
        EDITOR[File Editor UI]
        VERSIONS[Version Control]
    end
    
    subgraph "Test Scenarios"
        T1[Valid Files]
        T2[Invalid Format]
        T3[Large Files]
        T4[Malformed Data]
    end
    
    STORAGE --> API
    EDITOR --> STORAGE
    T1 --> STORAGE
    T2 --> STORAGE
    T3 --> STORAGE
    T4 --> STORAGE
    
    API --> VALIDATE
    VALIDATE --> QUEUE
    QUEUE --> PROCESSOR
```

### File API Test Harness

```typescript
// scripts/testing/file-api-test-harness.ts

import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

interface TestFile {
  name: string;
  path: string;
  expectedResult: 'success' | 'failure';
  modifications?: FileModification[];
}

interface FileModification {
  line: number;
  column?: number;
  newValue: string;
}

class FileAPITestHarness {
  private apiUrl: string;
  private testFilesDir: string;
  private workDir: string;
  
  constructor(environment: 'local' | 'test' | 'staging') {
    this.apiUrl = this.getApiUrl(environment);
    this.testFilesDir = '/data/test-files';
    this.workDir = '/tmp/file-api-tests';
  }
  
  private getApiUrl(env: string): string {
    const urls = {
      local: 'http://localhost:3000/api/files/process',
      test: 'http://oversight-mvp-test.azurecontainer.io/api/files/process',
      staging: 'http://oversight-mvp-staging.azurecontainer.io/api/files/process'
    };
    return urls[env];
  }
  
  // Test file upload
  async testFileUpload(file: TestFile): Promise<void> {
    console.log(`Testing file: ${file.name}`);
    
    // Apply modifications if needed
    const filePath = file.modifications 
      ? await this.modifyFile(file)
      : file.path;
    
    // Create form data
    const formData = new FormData();
    formData.append('file', fs.createReadStream(filePath));
    formData.append('processType', 'standard');
    
    try {
      // Upload file
      const response = await axios.post(this.apiUrl, formData, {
        headers: {
          ...formData.getHeaders(),
          'Authorization': `Bearer ${process.env.API_TOKEN}`
        },
        maxContentLength: Infinity,
        maxBodyLength: Infinity
      });
      
      // Check result
      if (file.expectedResult === 'success') {
        if (response.status === 200) {
          console.log(`✅ ${file.name}: Passed`);
          console.log(`   Processing ID: ${response.data.processingId}`);
        } else {
          console.error(`❌ ${file.name}: Failed - Expected success, got ${response.status}`);
        }
      } else {
        console.error(`❌ ${file.name}: Should have failed but succeeded`);
      }
      
    } catch (error) {
      if (file.expectedResult === 'failure') {
        console.log(`✅ ${file.name}: Correctly failed`);
      } else {
        console.error(`❌ ${file.name}: Unexpected failure`, error.message);
      }
    }
  }
  
  // Modify file for testing
  async modifyFile(file: TestFile): Promise<string> {
    const originalContent = fs.readFileSync(file.path, 'utf8');
    let lines = originalContent.split('\n');
    
    // Apply modifications
    file.modifications.forEach(mod => {
      if (mod.line < lines.length) {
        if (mod.column) {
          let line = lines[mod.line];
          lines[mod.line] = 
            line.substring(0, mod.column) + 
            mod.newValue + 
            line.substring(mod.column);
        } else {
          lines[mod.line] = mod.newValue;
        }
      }
    });
    
    // Save modified file
    const modifiedPath = path.join(this.workDir, `modified_${file.name}`);
    fs.writeFileSync(modifiedPath, lines.join('\n'));
    
    return modifiedPath;
  }
  
  // Run all tests
  async runAllTests(): Promise<void> {
    const testFiles: TestFile[] = [
      {
        name: 'valid_incident_data.csv',
        path: '/data/test-files/valid_incident_data.csv',
        expectedResult: 'success'
      },
      {
        name: 'malformed_headers.csv',
        path: '/data/test-files/valid_incident_data.csv',
        expectedResult: 'failure',
        modifications: [{
          line: 0,
          newValue: 'INVALID,HEADERS,HERE'
        }]
      },
      {
        name: 'large_dataset.csv',
        path: '/data/test-files/large_dataset.csv',
        expectedResult: 'success'
      },
      {
        name: 'sql_injection_attempt.csv',
        path: '/data/test-files/valid_incident_data.csv',
        expectedResult: 'failure',
        modifications: [{
          line: 1,
          column: 10,
          newValue: "'; DROP TABLE users; --"
        }]
      }
    ];
    
    console.log('Starting File API Tests...\n');
    
    for (const file of testFiles) {
      await this.testFileUpload(file);
      await this.wait(2000); // Rate limiting
    }
    
    console.log('\nTest run complete');
  }
  
  private wait(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Run tests
const harness = new FileAPITestHarness('test');
harness.runAllTests();
```

---

## 🔄 Jenkins Pipeline Integration

### Database State in Pipeline

```groovy
// Jenkinsfile additions for database state management

stage('Prepare Test Database') {
    steps {
        script {
            def dbState = params.DATABASE_STATE ?: '2'  // Default to framework
            
            sh """
                echo "Setting database to state ${dbState}"
                ./scripts/data/switch-db-state.sh ${dbState}
            """
        }
    }
}

stage('File API Testing') {
    parallel {
        stage('Valid Files') {
            steps {
                sh 'npm run test:file-api:valid'
            }
        }
        stage('Invalid Files') {
            steps {
                sh 'npm run test:file-api:invalid'
            }
        }
        stage('Performance') {
            steps {
                sh 'npm run test:file-api:performance'
            }
        }
    }
}

stage('Restore Known-Good') {
    when {
        expression { currentBuild.result == 'FAILURE' }
    }
    steps {
        sh './scripts/data/restore-known-good.sh'
    }
}
```

---

## 🎯 Test Data Scenarios

### Scenario Matrix

| Scenario | DB State | Test Files | Purpose |
|----------|----------|------------|---------|
| Unit Tests | Schema Only | Mock files | Isolated component testing |
| Integration | Framework | Small valid files | API contract testing |
| Load Testing | Full Data | Large files (100MB+) | Performance validation |
| Security | Framework | Malicious payloads | Security scanning |
| UAT | Full Data | Production-like files | User acceptance |
| Regression | Framework | Previous bug files | Prevent regressions |

---

## 🔧 Docker Compose Configuration

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  postgres-test:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: oversight_test
      POSTGRES_USER: oversight_admin
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./scripts/data/init:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U oversight_admin"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  file-storage:
    image: mcr.microsoft.com/azure-storage/azurite
    ports:
      - "10000:10000"  # Blob service
      - "10001:10001"  # Queue service
    volumes:
      - ./data/azurite:/data
    command: azurite --blobHost 0.0.0.0 --queueHost 0.0.0.0
  
  app-test:
    image: acrsecdevopsdev.azurecr.io/oversight-mvp:${VERSION}
    depends_on:
      postgres-test:
        condition: service_healthy
      file-storage:
        condition: service_started
    environment:
      DATABASE_URL: postgresql://oversight_admin:${DB_PASSWORD}@postgres-test:5432/oversight_test
      FILE_STORAGE_URL: http://file-storage:10000/devstoreaccount1
      NODE_ENV: test
    ports:
      - "3000:3000"
    volumes:
      - ./test-files:/app/test-files
```

---

## 📋 Known-Good Management

### Snapshot Schedule

```yaml
Daily Snapshots:
  - Time: 02:00 UTC
  - Retention: 7 days
  - States: All (1, 2, 3)

Weekly Snapshots:
  - Day: Sunday
  - Time: 03:00 UTC
  - Retention: 4 weeks
  - States: Framework (2), Full (3)

Release Snapshots:
  - Trigger: Before each release
  - Retention: Permanent
  - States: All (1, 2, 3)
  - Naming: release-{version}-state{n}.sql.gz
```

### Restore Procedures

```bash
#!/bin/bash
# scripts/data/restore-known-good.sh

# Restore to last known-good state
restore_known_good() {
    local state=${1:-2}  # Default to framework state
    
    echo "Restoring to last known-good state $state"
    
    # Find latest known-good backup
    LATEST_BACKUP=$(az storage blob list \
        --container-name oversight-db-snapshots \
        --prefix "known-good-state${state}" \
        --query "sort_by([].{name:name, modified:properties.lastModified}, &modified)[-1].name" \
        -o tsv)
    
    if [ -z "$LATEST_BACKUP" ]; then
        echo "ERROR: No known-good backup found for state $state"
        exit 1
    fi
    
    # Download backup
    az storage blob download \
        --container-name oversight-db-snapshots \
        --name "$LATEST_BACKUP" \
        --file "/tmp/${LATEST_BACKUP}"
    
    # Decompress
    gunzip "/tmp/${LATEST_BACKUP}"
    
    # Restore
    psql -h $DB_HOST -U $DB_USER -d $DB_NAME < "/tmp/${LATEST_BACKUP%.gz}"
    
    echo "✅ Restored to known-good: $LATEST_BACKUP"
}
```

---

## 🚀 Quick Commands

### For Developers

```bash
# Switch database states
./scripts/data/switch-db-state.sh 1  # Schema only
./scripts/data/switch-db-state.sh 2  # Framework data
./scripts/data/switch-db-state.sh 3  # Full data

# Test file API
npm run test:file-api               # Run all file API tests
npm run test:file-api:interactive   # Interactive file editor

# Restore known-good
./scripts/data/restore-known-good.sh 2  # Restore framework state

# Create new test file
./scripts/testing/create-test-file.sh --type incident --records 1000
```

### For DevOps

```bash
# Create snapshots
./scripts/data/create-all-snapshots.sh

# Schedule snapshot job
kubectl apply -f k8s/cronjobs/db-snapshot.yaml

# Verify backups
az storage blob list \
    --container-name oversight-db-snapshots \
    --query "[?contains(name, 'state')].{name:name, size:properties.contentLength}" \
    -o table
```

---

## 📊 Monitoring & Alerts

### Key Metrics

```yaml
Database Health:
  - Connection pool usage
  - Query performance
  - Disk usage
  - Backup success rate

File API:
  - Upload success rate
  - Processing time
  - Queue depth
  - Error rate

Alerts:
  - Database state change (audit)
  - Backup failure
  - File processing timeout
  - Storage quota exceeded
```

---

## 🔐 Security Considerations

1. **Database Credentials**: Stored in Azure Key Vault
2. **File Sanitization**: All uploaded files scanned for malware
3. **SQL Injection Protection**: Parameterized queries only
4. **Access Control**: Role-based access to state switching
5. **Audit Trail**: All state changes logged
6. **Encryption**: Data encrypted at rest and in transit

---

This comprehensive data management strategy ensures reliable testing with proper state management and file API testing capabilities across all environments.