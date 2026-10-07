# Authentication

Choose the ``Credentials`` that match your remote so clone, fetch, pull and push can authenticate.

## Overview

Every network operation takes a ``Credentials`` value. The library calls back into it when the server asks for authentication. If the credentials do not fit the transport, the operation fails with a libgit2 error.

| Remote URL | Credentials |
| --- | --- |
| `https://…` with a token or password | `.plaintext(username:password:)` |
| `git@host:owner/repo.git` with a running SSH agent | `.sshAgent` |
| `git@host:owner/repo.git` with an in-memory key | `.sshMemory(username:publicKey:privateKey:passphrase:)` |
| Public repositories, or system-level auth | `.default` |

## HTTPS with a personal access token

Use the token as the password. The username is usually your account name (GitHub accepts any non-empty value).

```swift
let credentials = Credentials.plaintext(username: "jane", password: token)

let repository = try Repository.clone(
    from: URL(string: "https://github.com/owner/private-repo.git")!,
    to: destinationURL,
    credentials: credentials,
    proxy: nil
).get()
```

Create the token with read access to repository contents to clone and pull, and write access to push. Do not hard-code it: read it from the Keychain.

## SSH with the agent

`.sshAgent` uses the keys loaded into the system `ssh-agent`. The user name comes from the URL (`git@…`).

```swift
let origin = try repository.remote(named: "origin").get()
try repository.fetch(origin, credentials: .sshAgent, proxy: nil).get()
```

> Important: the remote URL must be an SSH URL such as `git@github.com:owner/repo.git`. With an HTTPS URL the agent is never asked.

The agent is not available inside the iOS sandbox. On iOS, use `.sshMemory`.

## SSH with an in-memory key

Provide the key material directly, which suits iOS apps that store keys in the Keychain.

```swift
let credentials = Credentials.sshMemory(
    username: "git",
    publicKey: publicKeyPEM,
    privateKey: privateKeyPEM,
    passphrase: passphrase
)

try repository.pull(
    remote: origin,
    branch: branch,
    author: "Jane Doe",
    email: "jane@example.com",
    credentials: credentials,
    proxy: nil,
    conflictResolver: { _, _ in .ours }
).get()
```

Pass an empty `passphrase` for an unencrypted key. The `username` is only used when the URL does not contain one.

## Storing secrets

- Keep tokens and private keys in the Keychain, never in source control or `UserDefaults`.
- Build the ``Credentials`` value right before the network call and let it go out of scope afterwards.

## Using a proxy

Pass a ``ProxyConfiguration`` to route traffic through a proxy:

```swift
let proxy = ProxyConfiguration(
    url: URL(string: "http://proxy.example.com:8080"),
    credential: ProxyCredential(username: "user", password: "secret")
)
try repository.fetch(origin, credentials: credentials, proxy: proxy).get()
```

With `nil`, libgit2 detects the proxy automatically from the environment.

## Troubleshooting

- **`authentication required` or `-1` on HTTPS**: check the token scope and that you pass `.plaintext`, not `.default`.
- **Fails only over SSH**: confirm the URL is `git@host:…`, the agent has the key (`ssh-add -l`), or switch to `.sshMemory`.
- **`push` is rejected**: the remote branch has commits you do not have; pull first, then push again.
