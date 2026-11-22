# Contributing

Pull requests (PRs) are welcome from everyone.

By participating in this project, you agree to abide by the [code of
conduct](CODE_OF_CONDUCT.md).

## Getting Started

- Ensure you have a [GitHub account](https://github.com/signup)
- [Search for similar
  issues](https://github.com/ro-ss/swift-cascading-configuration/issues)
- If one does not exist, [open a new issue](
    https://github.com/ro-ss/swift-cascading-configuration/issues/new/choose
  )
  - Select the appropriate issue template
  - Follow the instructions in the issue template

## Making Changes

This project uses [trunk-based development](https://trunkbaseddevelopment.com),
where `main` is the trunk.

- [Fork the repository](
    https://github.com/ro-ss/swift-cascading-configuration#fork-button
  ) on GitHub
- Clone your fork:
  `git clone git@github.com:your-username/swift-cascading-configuration.git`
- Create a topic branch instead of working directly on `main`
  - To branch a topic branch from `main` named, e.g., `feature`, run:
    `git checkout -b feature main`
- Commit logical units
- Follow the [project guidelines](AGENTS.md)
- Run `Scripts/format` before committing
- Run `Scripts/lint` before committing, then fix all lint violations
- Write tests
  - If you need help with tests, feel free to open a PR, then ask for help
- Write [good commit messages](
    https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
  )
- Push your topic branch to your fork, then submit a pull request (PR)
  - If your PR is not ready to be merged, create a draft PR

## Releases

- Release commits are tagged in the format of `v1.2.3`
- Releases (including release notes) are published on the [Releases
  page](https://github.com/ro-ss/swift-cascading-configuration/releases)

## Becoming a Contributor

To join the [team](https://github.com/orgs/ro-ss/teams/contributors), once a few
of your PRs have been accepted, [open an
issue](https://github.com/ro-ss/swift-cascading-configuration/issues/new) titled
"Add Contributor: @YourGitHubUsername".

## Project Lead Responsibilities

Project leads agree to the following terms:

- Project leads have full control, however, over the project's future direction
- If you are the sole project lead, but can no longer lead the project, either:
  - Find someone else to assume the project leadership who agrees to adhere to
    the existing terms
  - If you cannot find a new project lead:
    - Add an [unmaintained badge](https://unmaintained.tech) to the
      [README](README.md)
