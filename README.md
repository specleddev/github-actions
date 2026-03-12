# specleddev/github-actions

Reusable GitHub Actions for Spec Led Development.

## Available Actions

| Action | Purpose |
| --- | --- |
| `verify` | Runs `mix spec.check` against any checked-out repository through an isolated `specled_ex` runner. |

## `verify`

`verify` is language agnostic at the repository level.
It does not require the target repository to be an Elixir project.
The action provisions a temporary Mix runner, installs `specled_ex`, and points the task at the checked-out repository with `--root`.
When command verifications are enabled and the target repository has a `mix.exs`, the action also runs `mix deps.get` in the target repository before verification.
It restores shared Hex/Mix cache plus cached `deps/_build` state for both the isolated runner and any target Mix project.

### Basic Usage

```yaml
jobs:
  specs:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Spec Led checks
        uses: specleddev/github-actions/verify@v1
```

### With Diff Checks

```yaml
jobs:
  specs:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Spec Led checks
        uses: specleddev/github-actions/verify@v1
        with:
          diffcheck: "true"
          min_strength: linked
```

### Branch Testing

If you need to test an unpublished branch of this repo from another repository, check this repo out into the workflow and use the local path:

```yaml
jobs:
  specs:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout target repository
        uses: actions/checkout@v4

      - name: Checkout Spec Led GitHub Actions
        uses: actions/checkout@v4
        with:
          repository: specleddev/github-actions
          ref: my-branch
          path: .github/actions/specled-github-actions

      - name: Run Spec Led checks
        uses: ./.github/actions/specled-github-actions/verify
```

### Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `root` | `.` | Repository root relative to `GITHUB_WORKSPACE`. |
| `spec_dir` | `.spec` | Spec workspace path relative to `root`. |
| `backend_repo` | `specleddev/spec_led_ex` | GitHub repository for the `specled_ex` backend when `backend_path` is empty. |
| `backend_ref` | `main` | Git ref for the `specled_ex` backend. Pin a tag or SHA in production. |
| `backend_path` | `""` | Local checkout path for `specled_ex`. Overrides `backend_repo` and `backend_ref`. |
| `elixir_version` | `1.19.5` | Elixir version used for the isolated runner. |
| `otp_version` | `28.3.1` | OTP version used for the isolated runner. |
| `run_commands` | `"true"` | Whether `mix spec.check` executes command verifications. |
| `min_strength` | `""` | Optional minimum verification strength: `claimed`, `linked`, or `executed`. |
| `diffcheck` | `"false"` | Runs `mix spec.diffcheck` after `mix spec.check`. |
| `diff_base` | `""` | Optional base ref for `mix spec.diffcheck --base`. |
| `check_clean` | `"true"` | Fails if `.spec` changes after the checks run. |

## Testing

This repo tests the `verify` action against committed non-Elixir fixtures under [`fixtures/`](fixtures).
