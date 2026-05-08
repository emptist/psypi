# principles of the "repair" plan:

- where a thing is too difficult to deal with using gleam, write js (not ts), and replace them later when we know gleam better

- no mere repairing but real improving the gleam code quality, for example, uuid should not using string if we started using gleam from day 1, so it should be fixed

- fixing concepts before code, full discussion needed on psypi-commit, and perhaps any other troublesome issues

- spawning should be limited to the psypi itself, no spawning of pi later in code to avoid system overload