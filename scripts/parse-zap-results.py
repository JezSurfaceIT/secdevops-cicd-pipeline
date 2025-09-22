#!/usr/bin/env python3

import json
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any
import xml.etree.ElementTree as ET

class ZAPResultsParser:
    """Parse and analyze OWASP ZAP scan results"""
    
    def __init__(self, report_file: str, format: str = 'json'):
        self.report_file = report_file
        self.format = format
        self.alerts = []
        self.summary = {
            'High': 0,
            'Medium': 0,
            'Low': 0,
            'Informational': 0
        }
        self.thresholds = {
            'High': 0,      # No high severity allowed
            'Medium': 5,    # Maximum 5 medium severity
            'Low': 20,      # Maximum 20 low severity
            'Informational': 100  # Informational ignored
        }
    
    def parse(self) -> bool:
        """Parse the report file"""
        try:
            if self.format == 'json':
                return self.parse_json()
            elif self.format == 'xml':
                return self.parse_xml()
            else:
                print(f"Unsupported format: {self.format}")
                return False
        except Exception as e:
            print(f"Error parsing report: {e}")
            return False
    
    def parse_json(self) -> bool:
        """Parse JSON format report"""
        try:
            with open(self.report_file, 'r') as f:
                data = json.load(f)
            
            if 'alerts' in data:
                self.alerts = data['alerts']
            elif isinstance(data, list):
                self.alerts = data
            else:
                print("Unknown JSON structure")
                return False
            
            self.categorize_alerts()
            return True
        except Exception as e:
            print(f"Error parsing JSON: {e}")
            return False
    
    def parse_xml(self) -> bool:
        """Parse XML format report"""
        try:
            tree = ET.parse(self.report_file)
            root = tree.getroot()
            
            for alert in root.findall('.//alertitem'):
                alert_dict = {
                    'risk': alert.find('riskdesc').text.split(' ')[0] if alert.find('riskdesc') is not None else 'Informational',
                    'alert': alert.find('alert').text if alert.find('alert') is not None else 'Unknown',
                    'url': alert.find('uri').text if alert.find('uri') is not None else '',
                    'description': alert.find('desc').text if alert.find('desc') is not None else '',
                    'solution': alert.find('solution').text if alert.find('solution') is not None else '',
                    'confidence': alert.find('confidence').text if alert.find('confidence') is not None else 'Low',
                    'cwe': alert.find('cweid').text if alert.find('cweid') is not None else '0'
                }
                self.alerts.append(alert_dict)
            
            self.categorize_alerts()
            return True
        except Exception as e:
            print(f"Error parsing XML: {e}")
            return False
    
    def categorize_alerts(self):
        """Categorize alerts by severity"""
        for alert in self.alerts:
            risk = alert.get('risk', 'Informational')
            if risk in self.summary:
                self.summary[risk] += 1
    
    def generate_summary(self) -> str:
        """Generate a summary report"""
        total = sum(self.summary.values())
        
        report = []
        report.append("=" * 60)
        report.append("OWASP ZAP Security Scan Results")
        report.append("=" * 60)
        report.append(f"Report: {self.report_file}")
        report.append(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        report.append("Summary:")
        report.append("-" * 40)
        report.append(f"🔴 High:          {self.summary['High']}")
        report.append(f"🟡 Medium:        {self.summary['Medium']}")
        report.append(f"🔵 Low:           {self.summary['Low']}")
        report.append(f"⚪ Informational: {self.summary['Informational']}")
        report.append(f"📊 Total:         {total}")
        report.append("")
        
        return "\n".join(report)
    
    def generate_detailed_report(self) -> str:
        """Generate detailed findings report"""
        report = []
        
        # Group alerts by severity
        high_alerts = [a for a in self.alerts if a.get('risk') == 'High']
        medium_alerts = [a for a in self.alerts if a.get('risk') == 'Medium']
        
        if high_alerts:
            report.append("HIGH SEVERITY FINDINGS:")
            report.append("=" * 40)
            for alert in high_alerts[:5]:  # Show first 5
                report.append(f"⚠️  {alert.get('alert', 'Unknown')}")
                report.append(f"   URL: {alert.get('url', 'N/A')}")
                report.append(f"   CWE: {alert.get('cwe', 'N/A')}")
                report.append("")
        
        if medium_alerts:
            report.append("MEDIUM SEVERITY FINDINGS:")
            report.append("=" * 40)
            for alert in medium_alerts[:5]:  # Show first 5
                report.append(f"⚠️  {alert.get('alert', 'Unknown')}")
                report.append(f"   URL: {alert.get('url', 'N/A')}")
                report.append("")
        
        return "\n".join(report)
    
    def check_thresholds(self) -> tuple:
        """Check if findings exceed thresholds"""
        passed = True
        messages = []
        
        for severity, count in self.summary.items():
            if count > self.thresholds[severity]:
                passed = False
                messages.append(f"❌ {severity} severity exceeds threshold: {count} > {self.thresholds[severity]}")
            elif count > 0 and severity != 'Informational':
                messages.append(f"⚠️  {severity} severity: {count} findings")
        
        if passed:
            messages.append("✅ All security checks passed!")
        
        return passed, messages
    
    def generate_jenkins_report(self) -> Dict[str, Any]:
        """Generate report suitable for Jenkins"""
        passed, messages = self.check_thresholds()
        
        return {
            'passed': passed,
            'summary': self.summary,
            'total': sum(self.summary.values()),
            'messages': messages,
            'report_file': self.report_file,
            'timestamp': datetime.now().isoformat()
        }
    
    def export_sarif(self, output_file: str):
        """Export results in SARIF format for GitHub/Azure DevOps"""
        sarif = {
            "version": "2.1.0",
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "runs": [{
                "tool": {
                    "driver": {
                        "name": "OWASP ZAP",
                        "version": "2.14.0",
                        "rules": []
                    }
                },
                "results": []
            }]
        }
        
        for alert in self.alerts:
            if alert.get('risk') in ['High', 'Medium']:
                result = {
                    "ruleId": f"ZAP-{alert.get('cwe', '0')}",
                    "level": "error" if alert.get('risk') == 'High' else "warning",
                    "message": {
                        "text": alert.get('alert', 'Security Issue')
                    },
                    "locations": [{
                        "physicalLocation": {
                            "artifactLocation": {
                                "uri": alert.get('url', 'unknown')
                            }
                        }
                    }]
                }
                sarif["runs"][0]["results"].append(result)
        
        with open(output_file, 'w') as f:
            json.dump(sarif, f, indent=2)
        
        print(f"SARIF report exported to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Parse OWASP ZAP scan results')
    parser.add_argument('report_file', help='Path to ZAP report file')
    parser.add_argument('--format', choices=['json', 'xml'], default='json', 
                       help='Report format (default: json)')
    parser.add_argument('--detailed', action='store_true', 
                       help='Show detailed findings')
    parser.add_argument('--jenkins', action='store_true',
                       help='Output Jenkins-compatible JSON')
    parser.add_argument('--sarif', help='Export to SARIF format file')
    parser.add_argument('--threshold-high', type=int, default=0,
                       help='Maximum allowed high severity findings')
    parser.add_argument('--threshold-medium', type=int, default=5,
                       help='Maximum allowed medium severity findings')
    
    args = parser.parse_args()
    
    # Create parser instance
    parser = ZAPResultsParser(args.report_file, args.format)
    
    # Update thresholds if provided
    if args.threshold_high is not None:
        parser.thresholds['High'] = args.threshold_high
    if args.threshold_medium is not None:
        parser.thresholds['Medium'] = args.threshold_medium
    
    # Parse the report
    if not parser.parse():
        sys.exit(1)
    
    # Generate output based on options
    if args.jenkins:
        # Output Jenkins-compatible JSON
        result = parser.generate_jenkins_report()
        print(json.dumps(result, indent=2))
        sys.exit(0 if result['passed'] else 1)
    elif args.sarif:
        # Export to SARIF format
        parser.export_sarif(args.sarif)
    else:
        # Standard output
        print(parser.generate_summary())
        
        if args.detailed:
            print("")
            print(parser.generate_detailed_report())
        
        # Check thresholds
        print("")
        passed, messages = parser.check_thresholds()
        for message in messages:
            print(message)
        
        sys.exit(0 if passed else 1)

if __name__ == "__main__":
    main()