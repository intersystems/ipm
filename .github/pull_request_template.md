## Description
- Link the issue using the [magic closing words](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/using-keywords-in-issues-and-pull-requests#linking-a-pull-request-to-an-issue).
- Provide a summary of the change and how it addresses the issue (e.g. if it is a bug, explain the root cause of the bug and how this change fixes it).
- Include any other necessary context, especially if any section warrants special reviewer attention.

## Testing
How has this change been tested? Have you added unit or integration tests as appropriate?

## Checklist
<!-- You can select a checkbox by changing "[ ]" to "[x]" -->
- [ ] This branch has the latest changes from the `main` branch rebased or merged.
- [ ] Changelog entry added.
- [ ] Unit (`zpm test -only`) and integration tests (`zpm verify -only`) pass.
- [ ] Style matches the style guide in the [contributing guide](https://github.com/intersystems/ipm/blob/main/CONTRIBUTING.md#style-guide).
- [ ] Documentation has been/will be updated
  - Source controlled docs, e.g. README.md, should be included in this PR and Wiki changes should be made after this PR is merged (add an extra issue for this if needed)
- [ ] Pull request correctly renders in the "Preview" tab.
