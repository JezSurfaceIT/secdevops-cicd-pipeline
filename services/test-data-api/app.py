#!/usr/bin/env python3

from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
import os
import time
import logging
from datetime import datetime
from typing import Dict, Any

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', '10.40.1.20'),
    'port': os.environ.get('DB_PORT', '5432'),
    'database': os.environ.get('DB_NAME', 'oversight_test'),
    'user': os.environ.get('DB_USER', 'testadmin'),
    'password': os.environ.get('DB_PASSWORD', 'TestPassword123!')
}

# Available database states
DB_STATES = {
    'schema-only': {
        'description': 'Empty database with schema only',
        'sql_file': '/app/sql/states/schema-only.sql'
    },
    'framework': {
        'description': 'Basic framework data (users, roles, settings)',
        'sql_file': '/app/sql/states/framework-data.sql'
    },
    'full': {
        'description': 'Complete test data set',
        'sql_file': '/app/sql/states/full-test-data.sql'
    }
}

# Current state tracking
current_state = 'unknown'
last_state_change = None


def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise


def execute_sql_file(filepath: str) -> bool:
    """Execute SQL file against database"""
    try:
        with open(filepath, 'r') as file:
            sql = file.read()
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Execute SQL in transaction
        cursor.execute(sql)
        conn.commit()
        
        cursor.close()
        conn.close()
        
        return True
    except Exception as e:
        logger.error(f"Failed to execute SQL file {filepath}: {e}")
        if conn:
            conn.rollback()
            conn.close()
        return False


def get_current_state() -> str:
    """Detect current database state based on data presence"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check for tables
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public'
        """)
        table_count = cursor.fetchone()[0]
        
        if table_count == 0:
            state = 'empty'
        else:
            # Check for data in key tables
            cursor.execute("""
                SELECT 
                    (SELECT COUNT(*) FROM users) as user_count,
                    (SELECT COUNT(*) FROM projects) as project_count,
                    (SELECT COUNT(*) FROM test_results) as test_count
            """)
            result = cursor.fetchone()
            
            if result:
                user_count = result[0] if result[0] else 0
                project_count = result[1] if result[1] else 0
                test_count = result[2] if result[2] else 0
                
                if user_count == 0:
                    state = 'schema-only'
                elif user_count > 0 and test_count == 0:
                    state = 'framework'
                else:
                    state = 'full'
            else:
                state = 'schema-only'
        
        cursor.close()
        conn.close()
        
        return state
    except Exception as e:
        logger.error(f"Failed to detect state: {e}")
        return 'unknown'


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        db_status = 'connected'
    except:
        db_status = 'disconnected'
    
    return jsonify({
        'status': 'healthy',
        'database': db_status,
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/test/db-state', methods=['GET'])
def get_db_state():
    """Get current database state"""
    global current_state, last_state_change
    
    current_state = get_current_state()
    
    return jsonify({
        'current_state': current_state,
        'available_states': list(DB_STATES.keys()),
        'state_descriptions': {k: v['description'] for k, v in DB_STATES.items()},
        'last_change': last_state_change.isoformat() if last_state_change else None
    })


@app.route('/api/test/db-state', methods=['POST'])
def set_db_state():
    """Switch database to specified state"""
    global current_state, last_state_change
    
    data = request.get_json()
    if not data or 'state' not in data:
        return jsonify({'error': 'Missing state parameter'}), 400
    
    requested_state = data['state']
    if requested_state not in DB_STATES:
        return jsonify({
            'error': f'Invalid state. Must be one of: {list(DB_STATES.keys())}'
        }), 400
    
    logger.info(f"Switching database to state: {requested_state}")
    start_time = time.time()
    
    # Execute state transition
    success = execute_sql_file(DB_STATES[requested_state]['sql_file'])
    
    if success:
        current_state = requested_state
        last_state_change = datetime.utcnow()
        duration = time.time() - start_time
        
        logger.info(f"State transition completed in {duration:.2f} seconds")
        
        return jsonify({
            'status': 'success',
            'new_state': current_state,
            'duration_seconds': duration,
            'timestamp': last_state_change.isoformat()
        })
    else:
        return jsonify({
            'status': 'failed',
            'error': 'Failed to apply database state',
            'current_state': get_current_state()
        }), 500


@app.route('/api/test/db-reset', methods=['POST'])
def reset_db_state():
    """Reset database to current state (refresh data)"""
    global last_state_change
    
    current = get_current_state()
    if current == 'unknown' or current not in DB_STATES:
        return jsonify({
            'error': 'Cannot reset unknown state. Set a specific state first.'
        }), 400
    
    logger.info(f"Resetting database state: {current}")
    start_time = time.time()
    
    # Re-apply current state
    success = execute_sql_file(DB_STATES[current]['sql_file'])
    
    if success:
        last_state_change = datetime.utcnow()
        duration = time.time() - start_time
        
        logger.info(f"State reset completed in {duration:.2f} seconds")
        
        return jsonify({
            'status': 'success',
            'state': current,
            'duration_seconds': duration,
            'timestamp': last_state_change.isoformat()
        })
    else:
        return jsonify({
            'status': 'failed',
            'error': 'Failed to reset database state'
        }), 500


@app.route('/api/test/db-backup', methods=['POST'])
def backup_current_state():
    """Create backup of current database state"""
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    backup_file = f'/app/backups/backup_{timestamp}.sql'
    
    try:
        os.makedirs('/app/backups', exist_ok=True)
        
        # Create pg_dump backup
        os.system(f"PGPASSWORD={DB_CONFIG['password']} pg_dump -h {DB_CONFIG['host']} -U {DB_CONFIG['user']} -d {DB_CONFIG['database']} > {backup_file}")
        
        return jsonify({
            'status': 'success',
            'backup_file': backup_file,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        logger.error(f"Backup failed: {e}")
        return jsonify({
            'status': 'failed',
            'error': str(e)
        }), 500


@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    # Verify database connection on startup
    try:
        conn = get_db_connection()
        conn.close()
        logger.info("Database connection verified")
    except Exception as e:
        logger.error(f"Cannot connect to database: {e}")
    
    # Run Flask app
    app.run(host='0.0.0.0', port=5000, debug=os.environ.get('DEBUG', 'false').lower() == 'true')