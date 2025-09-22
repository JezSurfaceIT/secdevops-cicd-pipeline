# Playwright Azure Configuration Guide
## Complete Setup for Azure Test Environment

**Version:** 1.0  
**Date:** 2025-09-21  
**Author:** Winston - System Architect

---

## 🎭 Playwright Configuration Files

### Main Playwright Config

```typescript
// playwright.config.azure.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  
  // Azure-specific timeout settings
  timeout: process.env.CI ? 60000 : 30000,
  globalTimeout: process.env.CI ? 60 * 60 * 1000 : 30 * 60 * 1000,
  
  // Parallel execution for Azure
  workers: process.env.CI ? 4 : undefined,
  fullyParallel: true,
  
  // Retry configuration for flaky tests
  retries: process.env.CI ? 2 : 0,
  
  // Reporter configuration
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['./reporters/azure-reporter.ts'],
    ['./reporters/tech-debt-reporter.ts']
  ],
  
  use: {
    // Base URL for Azure test environment
    baseURL: process.env.APP_URL || 'http://oversight-mvp-test.azurecontainer.io',
    
    // Authentication state
    storageState: 'auth/user.json',
    
    // Screenshot and video on failure
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
    
    // Viewport
    viewport: { width: 1920, height: 1080 },
    
    // Network
    ignoreHTTPSErrors: true,
    
    // Timeouts
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },

  // Project configuration for different browsers
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
        }
      },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  // Web server configuration for local testing
  webServer: process.env.CI ? undefined : {
    command: 'npm run start:test',
    port: 3000,
    timeout: 120 * 1000,
    reuseExistingServer: true,
  },
});
```

### Azure-Specific Reporter

```typescript
// reporters/azure-reporter.ts
import { Reporter, TestCase, TestResult, FullResult } from '@playwright/test/reporter';
import { BlobServiceClient } from '@azure/storage-blob';
import axios from 'axios';

export class AzureReporter implements Reporter {
  private results: any[] = [];
  private startTime: Date;
  private blobClient: BlobServiceClient;
  
  constructor() {
    this.startTime = new Date();
    const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
    if (connectionString) {
      this.blobClient = BlobServiceClient.fromConnectionString(connectionString);
    }
  }

  onTestBegin(test: TestCase) {
    console.log(`🎭 Starting test: ${test.title}`);
  }

  onTestEnd(test: TestCase, result: TestResult) {
    const testResult = {
      id: `${test.parent.title}-${test.title}`.replace(/\s+/g, '-'),
      title: test.title,
      suite: test.parent.title,
      file: test.location.file,
      line: test.location.line,
      status: result.status,
      duration: result.duration,
      error: result.error,
      attachments: result.attachments,
      retry: result.retry,
      workerIndex: result.workerIndex,
      startTime: result.startTime,
      steps: result.steps,
      stdout: result.stdout,
      stderr: result.stderr
    };

    this.results.push(testResult);

    // Send real-time update to dashboard
    this.sendToDashboard(testResult);
  }

  async onEnd(result: FullResult) {
    const summary = {
      status: result.status,
      startTime: this.startTime,
      endTime: new Date(),
      duration: Date.now() - this.startTime.getTime(),
      totalTests: this.results.length,
      passed: this.results.filter(r => r.status === 'passed').length,
      failed: this.results.filter(r => r.status === 'failed').length,
      skipped: this.results.filter(r => r.status === 'skipped').length,
      flaky: this.results.filter(r => r.retry > 0).length,
      results: this.results
    };

    // Upload to Azure Blob Storage
    await this.uploadToBlob(summary);
    
    // Send to Azure Application Insights
    await this.sendToAppInsights(summary);
    
    // Create feedback tickets for failures
    await this.createFeedbackTickets(summary);
  }

  private async uploadToBlob(summary: any) {
    if (!this.blobClient) return;
    
    const containerName = 'test-results';
    const blobName = `playwright-results-${Date.now()}.json`;
    const containerClient = this.blobClient.getContainerClient(containerName);
    const blockBlobClient = containerClient.getBlockBlobClient(blobName);
    
    const data = JSON.stringify(summary, null, 2);
    await blockBlobClient.upload(data, data.length);
    
    console.log(`📤 Results uploaded to Azure Blob: ${blobName}`);
  }

  private async sendToAppInsights(summary: any) {
    const telemetryClient = process.env.APP_INSIGHTS_KEY;
    if (!telemetryClient) return;

    try {
      await axios.post(
        `https://dc.services.visualstudio.com/v2/track`,
        {
          name: 'PlaywrightTestRun',
          time: new Date().toISOString(),
          instrumentation: { key: telemetryClient },
          data: {
            baseType: 'EventData',
            baseData: {
              name: 'TestRunComplete',
              properties: {
                totalTests: summary.totalTests,
                passed: summary.passed,
                failed: summary.failed,
                duration: summary.duration,
                environment: 'azure-test'
              }
            }
          }
        }
      );
    } catch (error) {
      console.error('Failed to send to App Insights:', error);
    }
  }

  private async createFeedbackTickets(summary: any) {
    const failures = summary.results.filter(r => r.status === 'failed');
    
    for (const failure of failures) {
      // Analyze failure type
      const issueType = this.categorizeFailure(failure);
      
      // Create appropriate ticket
      if (issueType === 'test-script') {
        await this.createTestImprovementTicket(failure);
      } else if (issueType === 'application') {
        await this.createBugTicket(failure);
      } else if (issueType === 'environment') {
        await this.createEnvironmentTicket(failure);
      }
    }
  }

  private categorizeFailure(failure: any): string {
    const error = failure.error?.message || '';
    
    if (error.includes('Timeout') || error.includes('waiting for')) {
      return 'test-script'; // Likely a test issue
    } else if (error.includes('500') || error.includes('Error')) {
      return 'application'; // Application error
    } else if (error.includes('connect') || error.includes('network')) {
      return 'environment'; // Environment issue
    }
    
    return 'unknown';
  }

  private async sendToDashboard(result: any) {
    // Send real-time updates to Grafana/dashboard
    try {
      await axios.post(
        process.env.DASHBOARD_WEBHOOK_URL || 'http://localhost:3001/test-update',
        result
      );
    } catch (error) {
      // Silent fail - don't interrupt tests
    }
  }
}
```

### Tech Debt Reporter

```typescript
// reporters/tech-debt-reporter.ts
import { Reporter, TestCase, TestResult } from '@playwright/test/reporter';
import * as fs from 'fs';
import * as path from 'path';

export class TechDebtReporter implements Reporter {
  private debtAnalysis: Map<string, any> = new Map();

  onTestEnd(test: TestCase, result: TestResult) {
    const testPath = test.location.file;
    const testCode = this.readTestCode(testPath);
    
    const analysis = this.analyzeTestDebt(testCode, test.title);
    this.debtAnalysis.set(`${testPath}:${test.title}`, analysis);
  }

  private readTestCode(filePath: string): string {
    try {
      return fs.readFileSync(filePath, 'utf8');
    } catch {
      return '';
    }
  }

  private analyzeTestDebt(code: string, testName: string): any {
    const issues = [];
    let debtScore = 0;

    // Check for hardcoded values
    const hardcodedPatterns = [
      /url: ['"]https?:\/\/[^'"]+['"]/g,
      /password: ['"][^'"]+['"]/g,
      /email: ['"][^@]+@[^'"]+['"]/g,
      /waitForTimeout\(\d+\)/g,
      /sleep\(\d+\)/g
    ];

    hardcodedPatterns.forEach(pattern => {
      const matches = code.match(pattern);
      if (matches) {
        issues.push({
          type: 'hardcoded-value',
          count: matches.length,
          examples: matches.slice(0, 3)
        });
        debtScore += matches.length * 2;
      }
    });

    // Check for missing page objects
    if (!code.includes('Page') && !code.includes('Component')) {
      issues.push({
        type: 'missing-page-object',
        recommendation: 'Extract UI interactions to Page Object Model'
      });
      debtScore += 3;
    }

    // Check for assertion quality
    const assertions = code.match(/expect\([^)]+\)\./g) || [];
    if (assertions.length === 0) {
      issues.push({
        type: 'no-assertions',
        recommendation: 'Add meaningful assertions'
      });
      debtScore += 5;
    }

    // Check test length
    const lines = code.split('\n').length;
    if (lines > 100) {
      issues.push({
        type: 'test-too-long',
        lines: lines,
        recommendation: 'Break into smaller, focused tests'
      });
      debtScore += Math.floor(lines / 100) * 2;
    }

    // Check for try-catch abuse
    const tryCatchBlocks = code.match(/try\s*{[\s\S]*?catch/g) || [];
    if (tryCatchBlocks.length > 0) {
      issues.push({
        type: 'exception-swallowing',
        count: tryCatchBlocks.length,
        recommendation: 'Handle exceptions properly or let them fail the test'
      });
      debtScore += tryCatchBlocks.length * 3;
    }

    return {
      testName,
      debtScore,
      issues,
      priority: debtScore > 10 ? 'high' : debtScore > 5 ? 'medium' : 'low',
      estimatedRefactorHours: Math.ceil(debtScore / 3)
    };
  }

  async onEnd() {
    const report = {
      timestamp: new Date().toISOString(),
      totalTests: this.debtAnalysis.size,
      totalDebtScore: Array.from(this.debtAnalysis.values())
        .reduce((sum, a) => sum + a.debtScore, 0),
      highPriorityCount: Array.from(this.debtAnalysis.values())
        .filter(a => a.priority === 'high').length,
      tests: Array.from(this.debtAnalysis.entries()).map(([key, value]) => ({
        id: key,
        ...value
      }))
    };

    // Save report
    fs.writeFileSync(
      'tech-debt-report.json',
      JSON.stringify(report, null, 2)
    );

    // Create improvement tickets for high-priority items
    const highPriorityTests = report.tests.filter(t => t.priority === 'high');
    for (const test of highPriorityTests) {
      await this.createImprovementTicket(test);
    }

    console.log(`\n📊 Tech Debt Report Generated`);
    console.log(`Total Debt Score: ${report.totalDebtScore}`);
    console.log(`High Priority Tests: ${report.highPriorityCount}`);
  }

  private async createImprovementTicket(test: any) {
    // Implementation would create JIRA/Azure DevOps tickets
    console.log(`📝 Creating improvement ticket for: ${test.testName}`);
  }
}
```

### Docker Compose for Test Execution

```yaml
# docker-compose.playwright-azure.yml
version: '3.8'

services:
  playwright-runner:
    build:
      context: .
      dockerfile: Dockerfile.playwright
    environment:
      - APP_URL=http://oversight-mvp-test.azurecontainer.io
      - HEADLESS=true
      - WORKERS=4
      - AZURE_STORAGE_CONNECTION_STRING=${AZURE_STORAGE_CONNECTION_STRING}
      - APP_INSIGHTS_KEY=${APP_INSIGHTS_KEY}
      - JIRA_URL=${JIRA_URL}
      - JIRA_TOKEN=${JIRA_TOKEN}
    volumes:
      - ./tests:/tests
      - ./test-results:/results
      - ./playwright-report:/playwright-report
    networks:
      - test-network
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
        reservations:
          cpus: '2'
          memory: 2G

  test-db:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: test_db
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_pass
    volumes:
      - test-db-data:/var/lib/postgresql/data
    networks:
      - test-network

  redis-cache:
    image: redis:alpine
    networks:
      - test-network

  report-server:
    image: nginx:alpine
    volumes:
      - ./playwright-report:/usr/share/nginx/html:ro
    ports:
      - "8080:80"
    networks:
      - test-network

networks:
  test-network:
    driver: bridge

volumes:
  test-db-data:
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines-playwright.yml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - tests/**
      - playwright.config.ts

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: playwright-secrets
  - name: PLAYWRIGHT_BROWSERS_PATH
    value: $(Pipeline.Workspace)/pw-browsers

stages:
  - stage: TestQuality
    displayName: 'Test Quality Analysis'
    jobs:
      - job: AnalyzeTechDebt
        displayName: 'Analyze Test Technical Debt'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '18.x'
          
          - script: |
              npm ci
              npm run analyze:tech-debt
              npm run lint:tests
            displayName: 'Run Tech Debt Analysis'
          
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: '**/tech-debt-report.xml'
              testRunTitle: 'Tech Debt Analysis'

  - stage: PlaywrightTests
    displayName: 'Playwright Test Execution'
    jobs:
      - job: RunPlaywrightTests
        displayName: 'Run Playwright Tests'
        strategy:
          matrix:
            chromium:
              browser: chromium
            firefox:
              browser: firefox
            webkit:
              browser: webkit
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '18.x'
          
          - task: Cache@2
            inputs:
              key: 'playwright | "$(Agent.OS)" | package-lock.json'
              path: $(PLAYWRIGHT_BROWSERS_PATH)
            displayName: 'Cache Playwright Browsers'
          
          - script: |
              npm ci
              npx playwright install --with-deps $(browser)
            displayName: 'Install Dependencies'
          
          - script: |
              export APP_URL=$(APP_URL_TEST)
              npx playwright test --project=$(browser)
            displayName: 'Run $(browser) Tests'
            env:
              CI: true
              APP_URL_TEST: $(APP_URL_TEST)
              AZURE_STORAGE_CONNECTION_STRING: $(AZURE_STORAGE_CONNECTION_STRING)
          
          - task: PublishTestResults@2
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: '**/junit.xml'
              testRunTitle: 'Playwright $(browser) Tests'
          
          - task: PublishHtmlReport@1
            condition: succeededOrFailed()
            inputs:
              reportDir: playwright-report
              tabName: 'Playwright Report'

  - stage: FeedbackLoop
    displayName: 'Process Test Feedback'
    condition: always()
    jobs:
      - job: ProcessFeedback
        displayName: 'Create Improvement Tickets'
        steps:
          - script: |
              node scripts/process-test-feedback.js
              node scripts/create-improvement-tickets.js
            displayName: 'Process Feedback and Create Tickets'
          
          - script: |
              node scripts/update-test-metrics-dashboard.js
            displayName: 'Update Metrics Dashboard'
```

---

## 🚀 Quick Setup Commands

### Initial Setup
```bash
# Install Playwright
npm init playwright@latest

# Install additional reporters
npm install @azure/storage-blob applicationinsights

# Configure for Azure
cp playwright.config.azure.ts playwright.config.ts

# Install browsers
npx playwright install --with-deps
```

### Run Tests Locally
```bash
# Run all tests
npx playwright test

# Run specific project
npx playwright test --project=chromium

# Run with UI mode
npx playwright test --ui

# Debug mode
npx playwright test --debug
```

### Deploy to Azure
```bash
# Build Docker image
docker build -f Dockerfile.playwright -t playwright-runner .

# Push to ACR
az acr build --registry acrsecdevopsdev --image playwright-runner:latest .

# Deploy to AKS
kubectl apply -f k8s/playwright-deployment.yaml
```

---

This configuration provides a complete Playwright setup optimized for Azure test environments with comprehensive tech debt tracking and feedback mechanisms.