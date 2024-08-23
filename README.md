# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your [tSQLt](https://tsqlt.org/) tests.

## Index <!-- omit in toc -->

- [build-database-ci-action](#build-database-ci-action)
  - [Inputs](#inputs)
  - [Usage Examples](#usage-examples)
  - [Contributing](#contributing)
    - [Incrementing the Version](#incrementing-the-version)
    - [Source Code Changes](#source-code-changes)
    - [Updating the README.md](#updating-the-readmemd)
  - [Code of Conduct](#code-of-conduct)
  - [License](#license)

## Inputs

| Parameter                        | Is Required                                                                                | Default | Description                                                                                                                                                                                                                                                                                                                        |
|----------------------------------|--------------------------------------------------------------------------------------------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `db-server-name`                 | **Yes**                                                                                    | N/A     | The name of the database server to build the database on.                                                                                                                                                                                                                                                                          |
| `db-server-port`                 | **No**                                                                                     | 1433    | The port that the database server listens on.                                                                                                                                                                                                                                                                                      |
| `db-name`                        | **Yes**                                                                                    | N/A     | The name of the database to build.                                                                                                                                                                                                                                                                                                 |
| `use-integrated-security`        | **No**                                                                                     | false   | Use domain integrated security. This only works on windows. If running on a linux runner, set this to false or don't specify a value. If false, a db-username and db-password should be specified; if they aren't then the action will attempt to use integrated security. If true, those parameters will be ignored if specified. |
| `trust-server-certificate`       | **No**                                                                                     | false   | Trust Server Certificate parameter will be added to sqlcmd connections strings.  Set to true when certificate for server is self signed.                                                                                                                                                                                           |
| `db-username`                    | **No**: if `use-integrated-security: false`<br>**Yes**: if `use-integrated-security: true` | N/A     | The username to log into the database with. If not set, then integrated security will be used.                                                                                                                                                                                                                                     |
| `db-password`                    | **No**: if `use-integrated-security: false`<br>**Yes**: if `use-integrated-security: true` | N/A     | The password associated with the db-username used for login.                                                                                                                                                                                                                                                                       |
| `migration-files-path`           | **Yes**                                                                                    | N/A     | The path to the base directory containing the migration files to process with flyway. Can be a comma separated list of directories.                                                                                                                                                                                                |
| `install-mock-db-objects`        | **No**                                                                                     | false   | Specifies whether mock db objects should be used to fill out dependencies. If set to true mock-db-object-nuget-feed-url must also be set, otherwise an error will occur. The expected value is true or false.                                                                                                                      |
| `mock-db-object-dependency-list` | **No**                                                                                     | N/A     | A json string containing a list of objects with the name of the dependency package, the version, the url where the package is stored, and optionally a bearer token for authentication.                                                                                                                                            |
| `incremental`                    | **No**                                                                                     | false   | Specifies whether to drop and recreate the database before building, or apply to the current database. The expected value is true or false. If true, the create-database-file property will not be used.                                                                                                                           |
| `create-database-file`           | **No**: if `incremental: true`<br>**Yes**: if `incremental: false`                         | N/A     | The file path to the sql file that initializes the database. This script will only be run if the incremental property is false.                                                                                                                                                                                                    |
| `run-tests`                      | **No**                                                                                     | false   | Specifies whether or not to run tests. The expected values are true and false. If true, test-files-path should also be set. If false, test-files-path will be ignored.                                                                                                                                                             |
| `test-files-path`                | **No**: if `run-tests: false`<br>**Yes**: if `run-tests: true`                             | N/A     | The path to the files with tSQLt tests.                                                                                                                                                                                                                                                                                            |
| `test-timeout`                   | **No**                                                                                     | 300     | An optional setting for the allowed wait time, in seconds, for the tests to execute. If tests sometimes hang, or shouldn't take longer than a certain amount of time, this parameter can be helpful.                                                                                                                               |
| `drop-db-after-build`            | **No**                                                                                     | false   | Specifies whether or not to drop the database after building. Set this to false if other steps in the job rely on the database existing.                                                                                                                                                                                           |
| `should-validate-migrations`     | **No**                                                                                     | false   | Determines whether flyway will validate the migration scripts before running them.                                                                                                                                                                                                                                                 |
| `seed-data`                      | **No**                                                                                     | false   | A switch specifying whether or not to seed data into the database.                                                                                                                                                                                                                                                                 |
| `seed-data-files-path`           | **No**                                                                                     | N/A     | The path to the files with seeding database.                                                                                                                                                                                                                                                                                       |
| `managed-schemas`                | **No**                                                                                     | dbo     | A comma separated list of schemas that are to be managed by flyway.                                                                                                                                                                                                                                                                |

The `mock-db-object-dependency-list` should be a json array of objects with the following properties:

```json
{
  "version": "1.0.0",
  "packageName": "some_package",
  "nugetUrl": "https://www.some-nuget-repo.com",
  "authToken": "ghp_fdijlfdsakeizdkliejfezejw"
}
```

**Notes**

- The `authToken` property is optionally used for nuget sources that require a bearer token, such as GitHub Packages. It should not be included if it is unnecessary.
- The `nugetUrl` for GitHub Packages can be pretty tricky to lookup, so for reference the pattern is as follows: `https://nuget.pkg.github.com/<owner>/download/<package-name>/<version>/<file-name>.nupkg`. Here's an example of how that could look if this repo were publishing a package called `MyDbObject`: `https://nuget.pkg.github.com/im-open/download/MyDbObject/1.0.0/MyDbObject.1.0.0.nupkg`.

## Usage Examples

```yml
jobs:
  build-database:
    runs-on: im-linux
    steps:
      - uses: actions/checkout@v3

      - name: Install Flyway
        uses: im-open/setup-flyway@v1
        with:
          version: 7.2.0

      - name: Build Database
        # You may also reference the major or major.minor version
        uses: im-open/build-database-ci-action@v3.3.1
        with:
          db-server-name: localhost
          db-server-port: 1433
          db-name: MyLocalDB
          use-integrated-security: false
          trust-server-certificate: true # Required on windows vm runners to be set to true
          db-username: sa
          db-password: ${{ secrets.DB_PASSWORD }}
          migration-files-path: ./path/to/migrations
          install-mock-db-objects: true
          mock-db-object-dependency-list: '[{"version":"1.0.0","packageName":"dbo.Something","nugetUrl":"https://nuget.pkg.github.com/my-org/download/Something/1.0.0/dbo.Something.1.0.0.nupkg","authToken":"ghp_dkfsjakldafl"},{"version":"1.2.0","packageName":"dbo.SomeOtherThing","nugetUrl":"https://nuget.pkg.github.com/my-org/download/SomeOtherThing/1.2.0/dbo.SomeOtherThing1.2.0.nupkg","authToken":"ghp_dkfsjakldafl"}]'
          incremental: false
          create-database-file: ./path/to/create-db.sql
          run-tests: true
          test-files-path: ./path/to/tsqlt/tests
          test-timeout: 120 # 2 minutes
          drop-db-after-build: false
          should-validate-migrations: false
          seed-data: true
          seed-data-files-path: ./path/to/seed/data/files
          managed-schemas: dbo,MyCustomSchema,AnotherSchema
```

If your migration script are spread over multiple directories, and there isn't a common parent directory that can be used, multiple migration directories can be specified:

```yml
jobs:
  build-database:
    runs-on: im-linux
    steps:
      - uses: actions/checkout@v3

      - name: Install Flyway
        uses: im-open/setup-flyway@v1
        with:
          version: 7.2.0

      - name: Build Database
        # You may also reference the major or major.minor version
        uses: im-open/build-database-ci-action@v3.3.1
        with:
          db-server-name: localhost
          db-server-port: 1433
          db-name: MyLocalDB
          migration-files-path: ./path/to/migrations,./another/path
```

## Contributing

When creating PRs, please review the following guidelines:

- [ ] The action code does not contain sensitive information.
- [ ] At least one of the commit messages contains the appropriate `+semver:` keywords listed under [Incrementing the Version] for major and minor increments.
- [ ] The README.md has been updated with the latest version of the action.  See [Updating the README.md] for details.

### Incrementing the Version

This repo uses [git-version-lite] in its workflows to examine commit messages to determine whether to perform a major, minor or patch increment on merge if [source code] changes have been made.  The following table provides the fragment that should be included in a commit message to active different increment strategies.

| Increment Type | Commit Message Fragment                     |
|----------------|---------------------------------------------|
| major          | +semver:breaking                            |
| major          | +semver:major                               |
| minor          | +semver:feature                             |
| minor          | +semver:minor                               |
| patch          | *default increment type, no comment needed* |

### Source Code Changes

The files and directories that are considered source code are listed in the `files-with-code` and `dirs-with-code` arguments in both the [build-and-review-pr] and [increment-version-on-merge] workflows.  

If a PR contains source code changes, the README.md should be updated with the latest action version.  The [build-and-review-pr] workflow will ensure these steps are performed when they are required.  The workflow will provide instructions for completing these steps if the PR Author does not initially complete them.

If a PR consists solely of non-source code changes like changes to the `README.md` or workflows under `./.github/workflows`, version updates do not need to be performed.

### Updating the README.md

If changes are made to the action's [source code], the [usage examples] section of this file should be updated with the next version of the action.  Each instance of this action should be updated.  This helps users know what the latest tag is without having to navigate to the Tags page of the repository.  See [Incrementing the Version] for details on how to determine what the next version will be or consult the first workflow run for the PR which will also calculate the next version.

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/main/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2023, Extend Health, LLC. Code released under the [MIT license](LICENSE).

<!-- Links -->
[Incrementing the Version]: #incrementing-the-version
[Updating the README.md]: #updating-the-readmemd
[source code]: #source-code-changes
[usage examples]: #usage-examples
[build-and-review-pr]: ./.github/workflows/build-and-review-pr.yml
[increment-version-on-merge]: ./.github/workflows/increment-version-on-merge.yml
[git-version-lite]: https://github.com/im-open/git-version-lite
