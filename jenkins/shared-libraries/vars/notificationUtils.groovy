#!/usr/bin/env groovy

def sendSuccess(Map config = [:]) {
    def jobName = config.jobName ?: env.JOB_NAME
    def buildNumber = config.buildNumber ?: env.BUILD_NUMBER
    def buildUrl = config.buildUrl ?: env.BUILD_URL
    def duration = config.duration ?: currentBuild.durationString
    def commitInfo = getCommitInfo()
    
    echo "Sending success notification for ${jobName} #${buildNumber}"
    
    def message = """
✅ *Build Successful*
*Job:* ${jobName}
*Build:* #${buildNumber}
*Duration:* ${duration}
*Commit:* ${commitInfo.sha} by ${commitInfo.author}
*Message:* ${commitInfo.message}
*Branch:* ${env.BRANCH_NAME ?: 'unknown'}
*View Build:* ${buildUrl}
"""
    
    sendSlackNotification(
        channel: '#ci-success',
        color: 'good',
        message: message
    )
    
    sendEmailNotification(
        subject: "✅ Build Success: ${jobName} #${buildNumber}",
        body: message,
        recipients: getSuccessRecipients()
    )
    
    if (config.sendToTeams) {
        sendTeamsNotification(
            webhookUrl: config.teamsWebhook,
            color: '00FF00',
            title: 'Build Successful',
            message: message
        )
    }
}

def sendFailure(Map config = [:]) {
    def jobName = config.jobName ?: env.JOB_NAME
    def buildNumber = config.buildNumber ?: env.BUILD_NUMBER
    def buildUrl = config.buildUrl ?: env.BUILD_URL
    def duration = config.duration ?: currentBuild.durationString
    def failureReason = config.failureReason ?: getFailureReason()
    def commitInfo = getCommitInfo()
    
    echo "Sending failure notification for ${jobName} #${buildNumber}"
    
    def message = """
❌ *Build Failed*
*Job:* ${jobName}
*Build:* #${buildNumber}
*Duration:* ${duration}
*Failure Reason:* ${failureReason}
*Commit:* ${commitInfo.sha} by ${commitInfo.author}
*Message:* ${commitInfo.message}
*Branch:* ${env.BRANCH_NAME ?: 'unknown'}
*View Build:* ${buildUrl}
*Console Output:* ${buildUrl}console
"""
    
    sendSlackNotification(
        channel: '#ci-failures',
        color: 'danger',
        message: message
    )
    
    sendEmailNotification(
        subject: "❌ Build Failed: ${jobName} #${buildNumber}",
        body: message + "\n\nLast 50 lines of console output:\n" + getConsoleOutput(50),
        recipients: getFailureRecipients()
    )
    
    if (config.sendToTeams) {
        sendTeamsNotification(
            webhookUrl: config.teamsWebhook,
            color: 'FF0000',
            title: 'Build Failed',
            message: message
        )
    }
    
    if (config.createJiraIssue) {
        createJiraIssue(
            summary: "Build Failure: ${jobName} #${buildNumber}",
            description: message,
            issueType: 'Bug',
            priority: 'High'
        )
    }
}

def sendWarning(Map config = [:]) {
    def jobName = config.jobName ?: env.JOB_NAME
    def buildNumber = config.buildNumber ?: env.BUILD_NUMBER
    def warningMessage = config.message
    
    if (!warningMessage) {
        error "Warning message is required"
    }
    
    echo "Sending warning notification: ${warningMessage}"
    
    def message = """
⚠️ *Build Warning*
*Job:* ${jobName}
*Build:* #${buildNumber}
*Warning:* ${warningMessage}
*Branch:* ${env.BRANCH_NAME ?: 'unknown'}
*View Build:* ${env.BUILD_URL}
"""
    
    sendSlackNotification(
        channel: '#ci-warnings',
        color: 'warning',
        message: message
    )
}

def sendDeploymentNotification(Map config = [:]) {
    def environment = config.environment
    def version = config.version
    def status = config.status
    
    if (!environment || !version || !status) {
        error "Environment, version, and status are required for deployment notification"
    }
    
    def emoji = status == 'success' ? '🚀' : '❌'
    def color = status == 'success' ? 'good' : 'danger'
    
    def message = """
${emoji} *Deployment ${status.capitalize()}*
*Environment:* ${environment}
*Version:* ${version}
*Deployed by:* ${env.BUILD_USER ?: 'Jenkins'}
*Time:* ${new Date().format('yyyy-MM-dd HH:mm:ss')}
"""
    
    sendSlackNotification(
        channel: '#deployments',
        color: color,
        message: message
    )
    
    if (environment == 'production') {
        sendEmailNotification(
            subject: "${emoji} Production Deployment: ${version}",
            body: message,
            recipients: getProductionRecipients()
        )
    }
}

def sendSecurityAlert(Map config = [:]) {
    def severity = config.severity
    def vulnerabilities = config.vulnerabilities
    def tool = config.tool
    
    if (!severity || !vulnerabilities) {
        error "Severity and vulnerabilities are required for security alert"
    }
    
    def emoji = severity == 'critical' ? '🔴' : severity == 'high' ? '🟠' : '🟡'
    def color = severity == 'critical' ? 'danger' : severity == 'high' ? 'warning' : 'warning'
    
    def message = """
${emoji} *Security Alert - ${severity.toUpperCase()}*
*Tool:* ${tool}
*Vulnerabilities Found:* ${vulnerabilities}
*Job:* ${env.JOB_NAME}
*Build:* #${env.BUILD_NUMBER}
*View Report:* ${env.BUILD_URL}artifact/security-report.html
"""
    
    sendSlackNotification(
        channel: '#security-alerts',
        color: color,
        message: message
    )
    
    if (severity == 'critical' || severity == 'high') {
        sendEmailNotification(
            subject: "${emoji} Security Alert: ${severity.toUpperCase()} vulnerabilities found",
            body: message,
            recipients: getSecurityRecipients(),
            priority: 'High'
        )
        
        if (config.createJiraIssue) {
            createJiraIssue(
                summary: "Security: ${severity.toUpperCase()} vulnerabilities in ${env.JOB_NAME}",
                description: message,
                issueType: 'Security',
                priority: severity == 'critical' ? 'Critical' : 'High',
                labels: ['security', severity]
            )
        }
    }
}

def sendQualityGateNotification(Map config = [:]) {
    def status = config.status
    def metrics = config.metrics ?: [:]
    
    def emoji = status == 'passed' ? '✅' : '❌'
    def color = status == 'passed' ? 'good' : 'danger'
    
    def message = """
${emoji} *Quality Gate ${status.capitalize()}*
*Job:* ${env.JOB_NAME}
*Build:* #${env.BUILD_NUMBER}
"""
    
    if (metrics) {
        message += "\n*Metrics:*\n"
        metrics.each { key, value ->
            message += "• ${key}: ${value}\n"
        }
    }
    
    message += "*View Report:* ${env.BUILD_URL}artifact/sonarqube-report.html"
    
    sendSlackNotification(
        channel: '#quality-gates',
        color: color,
        message: message
    )
}

def sendPerformanceAlert(Map config = [:]) {
    def metric = config.metric
    def threshold = config.threshold
    def actual = config.actual
    def degradation = config.degradation
    
    if (!metric || !threshold || !actual) {
        error "Metric, threshold, and actual values are required"
    }
    
    def message = """
📊 *Performance Alert*
*Metric:* ${metric}
*Threshold:* ${threshold}
*Actual:* ${actual}
*Degradation:* ${degradation}%
*Job:* ${env.JOB_NAME}
*Build:* #${env.BUILD_NUMBER}
"""
    
    sendSlackNotification(
        channel: '#performance',
        color: 'warning',
        message: message
    )
}

def sendCustomNotification(Map config = [:]) {
    def title = config.title
    def message = config.message
    def channel = config.channel ?: '#general'
    def color = config.color ?: 'default'
    def recipients = config.recipients
    
    if (!title || !message) {
        error "Title and message are required for custom notification"
    }
    
    if (config.slack != false) {
        sendSlackNotification(
            channel: channel,
            color: color,
            message: "*${title}*\n${message}"
        )
    }
    
    if (recipients) {
        sendEmailNotification(
            subject: title,
            body: message,
            recipients: recipients
        )
    }
}

private def sendSlackNotification(Map config) {
    if (!env.SLACK_WEBHOOK_URL) {
        echo "Slack webhook URL not configured, skipping Slack notification"
        return
    }
    
    try {
        slackSend(
            channel: config.channel,
            color: config.color,
            message: config.message,
            teamDomain: env.SLACK_TEAM_DOMAIN,
            tokenCredentialId: 'slack-token'
        )
    } catch (Exception e) {
        echo "Failed to send Slack notification: ${e.message}"
    }
}

private def sendEmailNotification(Map config) {
    def recipients = config.recipients ?: env.DEFAULT_RECIPIENTS
    
    if (!recipients) {
        echo "No email recipients configured, skipping email notification"
        return
    }
    
    try {
        emailext(
            subject: config.subject,
            body: config.body,
            to: recipients,
            mimeType: 'text/html',
            attachLog: config.attachLog ?: false,
            compressLog: config.compressLog ?: false,
            recipientProviders: [
                [$class: 'DevelopersRecipientProvider'],
                [$class: 'RequesterRecipientProvider']
            ]
        )
    } catch (Exception e) {
        echo "Failed to send email notification: ${e.message}"
    }
}

private def sendTeamsNotification(Map config) {
    if (!config.webhookUrl) {
        echo "Teams webhook URL not provided, skipping Teams notification"
        return
    }
    
    def payload = [
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": config.title,
        "themeColor": config.color,
        "title": config.title,
        "sections": [[
            "text": config.message
        ]]
    ]
    
    sh """
        curl -H "Content-Type: application/json" \
            -d '${groovy.json.JsonOutput.toJson(payload)}' \
            ${config.webhookUrl}
    """
}

private def createJiraIssue(Map config) {
    try {
        def issue = [
            fields: [
                project: [key: env.JIRA_PROJECT_KEY ?: 'DEV'],
                summary: config.summary,
                description: config.description,
                issuetype: [name: config.issueType],
                priority: [name: config.priority],
                labels: config.labels ?: []
            ]
        ]
        
        withCredentials([usernamePassword(
            credentialsId: 'jira-credentials',
            usernameVariable: 'JIRA_USER',
            passwordVariable: 'JIRA_TOKEN'
        )]) {
            sh """
                curl -u \$JIRA_USER:\$JIRA_TOKEN \
                    -X POST \
                    -H "Content-Type: application/json" \
                    -d '${groovy.json.JsonOutput.toJson(issue)}' \
                    ${env.JIRA_URL}/rest/api/2/issue/
            """
        }
    } catch (Exception e) {
        echo "Failed to create Jira issue: ${e.message}"
    }
}

private def getCommitInfo() {
    def commitSha = sh(
        script: "git rev-parse HEAD",
        returnStdout: true
    ).trim()
    
    def commitAuthor = sh(
        script: "git log -1 --pretty=format:'%an'",
        returnStdout: true
    ).trim()
    
    def commitMessage = sh(
        script: "git log -1 --pretty=format:'%s'",
        returnStdout: true
    ).trim()
    
    return [
        sha: commitSha.substring(0, 7),
        author: commitAuthor,
        message: commitMessage
    ]
}

private def getFailureReason() {
    def log = currentBuild.rawBuild.getLog(1000)
    
    if (log.any { it.contains('Test failed') }) {
        return 'Test failure'
    } else if (log.any { it.contains('Compilation failed') }) {
        return 'Compilation error'
    } else if (log.any { it.contains('Security scan failed') }) {
        return 'Security vulnerability detected'
    } else if (log.any { it.contains('Quality gate failed') }) {
        return 'Quality gate not passed'
    } else {
        return 'Unknown failure'
    }
}

private def getConsoleOutput(int lines = 50) {
    return currentBuild.rawBuild.getLog(lines).join('\n')
}

private def getSuccessRecipients() {
    return env.SUCCESS_RECIPIENTS ?: env.DEFAULT_RECIPIENTS
}

private def getFailureRecipients() {
    return env.FAILURE_RECIPIENTS ?: env.DEFAULT_RECIPIENTS
}

private def getProductionRecipients() {
    return env.PRODUCTION_RECIPIENTS ?: 'devops-team@example.com,product-owner@example.com'
}

private def getSecurityRecipients() {
    return env.SECURITY_RECIPIENTS ?: 'security-team@example.com,devops-team@example.com'
}

return this