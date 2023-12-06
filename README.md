# uid2-shared-actions

This repo contains shared actions and workflows that are consumed by the other uid2 workflows.

This simplifies the management and maintenance of the workflows.

## Tips and tricks

If you're trying to do something that should be simple, but can't find something that quite supports what you're trying to do, the [GitHub Script action](https://github.com/actions/github-script) gives you an authenticated GitHub API client and you can just provide a JavaScript script. For an example, see the "Tag commit" step in the [Commit, PR, and Merge](actions\commit-pr-and-merge\action.yaml) shared action.

If you use this and the script gets complicated, consider trying to find a simpler approach, or putting the script somewhere it can be maintained/tested outside of the YAML file.