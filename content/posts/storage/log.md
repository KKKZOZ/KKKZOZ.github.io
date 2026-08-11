---
title: "A Piece of: Logs"
tags:
  - Dev
date: 2024-05-13
toc: true
# draft: true
weight: 10
---

## Log Levels

Log levels for software applications have a rich history dating back to the 1980s. One of the earliest and most influential logging solutions for Unix systems, Syslog, introduced a range of severity levels, which provided the first standardized framework for categorizing log entries based on their impact or urgency.

The following are the levels defined by Syslog in descending order of severity:

- Emergency (`emerg`): indicates that the system is unusable and requires immediate attention.
- Alert (`alert`): indicates that immediate action is necessary to resolve a critical issue.
- Critical (`crit`): signifies critical conditions in the program that demand intervention to prevent system failure.
- Error (`error`): indicates error conditions that impair some operation but are less severe than critical situations.
- Warning (`warn`): signifies potential issues that may lead to errors or unexpected behavior in the future if not addressed.
- Notice (`notice`): applies to normal but significant conditions that may require monitoring.
- Informational (`info`): includes messages that provide a record of the normal operation of the system.
- Debug (`debug`): intended for logging detailed information about the system for debugging purposes.

> The specific log levels available to you may defer depending on the programming language, logging framework, or service in use. However, in most cases, you can expect to encounter levels such as `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, and `TRACE`.

### FATAL

The FATAL log level is reserved for recording the most severe issues in an application. When an entry is logged at this level, it indicates a critical failure that prevents the application from doing any further useful work. Typically, such entries are logged just before shutting down the application to prevent data corruption or other detrimental effects.

Examples of events that may be logged as FATAL errors include the following:

- Crucial configuration information is missing without fallback defaults.
- Loss of essential external dependencies or services required for core application operations (such as the database).
- Running out of disk space or memory on the server, causing the application to halt or become unresponsive.
- When a security breach or unauthorized access to sensitive data is detected.

### ERROR

The `ERROR` log level indicates error conditions within an application that hinder the execution of a specific operation. While the application can continue functioning at a reduced level of functionality or performance, **_`ERROR` logs signify issues that should be investigated promptly_**.

> Unlike FATAL messages, `ERROR` logs do not have the same sense of urgency, as the application can continue to do useful work.

Some examples of situations that are typically logged at the ERROR level include the following:

- External API or service failures impacting the application's functionality (after automated recovery attempts have failed).
- Network communication errors, such as connection timeouts or DNS resolution failures.
- Failure to create or update a resource in the system.
  An unexpected error, such as the failure to decode a JSON object.

### WARN

Events logged at the WARN level typically indicate that something unexpected has occurred, but the application can continue to function normally for the time being. It is also used to signify conditions that should be promptly addressed before they escalate into problems for the application.

Some examples of events that may be logged at the WARN level include the following:

- Resource consumption nearing predefined thresholds (such as memory, CPU, or bandwidth).
- Errors that the application can recover from without any significant impact.
- Outdated configuration settings that are not in line with recommended practices.
- An excessive number of failed login attempts indicating potential security threats.
- External API response times exceed acceptable thresholds.

### INFO

The INFO level captures events in the system that are significant to the application's business purpose. Such events are logged to show that the system is operating normally.

Production systems typically default to logging at this level so that a summary of the application's normal behavior is visible to anyone reviewing the logs.

Some events that are typically logged at the INFO level include the following:

- Changes in the state of an operation, such as transitioning from "PENDING" to "IN PROGRESS".
- The successful completion of scheduled jobs or tasks.
- Starting or stopping a service or application component.
- Records of important milestones or significant events within the application.
- Progress updates during long-running processes or tasks
- Information about system health checks or status reports.

### Controlling your application's log volume

Once you select your default level, all log entries with a severity **_lower than the default will be excluded_**.

For example, in production environments, it's common to set the default level to `INFO`, capturing only messages of `INFO` level or higher (`WARN`, `ERROR`, and `FATAL`). If you want to focus solely on problem indicators, you can set the default level to `WARN`

```go
func main() {
    // this logger is set to the INFO level
    logger := zerolog.New(os.Stdout).
        Level(zerolog.InfoLevel).
        With().
        Timestamp().
        Logger()

    logger.Trace().Msg("Trace message")
    logger.Debug().Msg("Debug message")
    logger.Info().Msg("Info message")
    logger.Warn().Msg("Warn message")
    logger.Warn().Msg("Error message")
    logger.Fatal().Msg("Fatal message")
}
```

Notice how the DEBUG and INFO logs are missing here:

```log
{"level":"info","time":"2023-06-06T11:54:28+01:00","message":"Info message"}
{"level":"warn","time":"2023-06-06T11:54:28+01:00","message":"Warn message"}
{"level":"warn","time":"2023-06-06T11:54:28+01:00","message":"Error message"}
{"level":"fatal","time":"2023-06-06T11:54:28+01:00","message":"Fatal message"}
```

Controlling the default log level is commonly achieved through environmental variables, allowing you to modify it without altering the code. However, keep in mind that restarting the application may be necessary to update the level to a different value.

```go
// set the log level from the environment
logLevel, err := zerolog.ParseLevel(os.Getenv("APP_LOG_LEVEL"))
if err != nil {
    // default to INFO if log level is not set in the environment
    logLevel = zerolog.InfoLevel
}

logger := zerolog.New(os.Stdout).
    Level(logLevel).
    With().
    Timestamp().
    Logger()
```
