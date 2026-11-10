# Hindsight

The shared long-term memory of pi and Hermes on the station. The models of fact extraction and of embeddings are set in [ai-models.nix](../../../../lib/ai-models.nix); a local database does not mean local processing — the content of a memory operation goes to the configured provider

## Access and the life of a fact

The API listens on loopback, and the work machines reach it through a proxy of the private network. The API and the MCP server need a token of their own from SOPS, and the OpenRouter key stays with the service of the station. The client configuration of pi is in [memory.nix](../../../../home-manager/programs/agents/pi/memory.nix), and that of Hermes in [hermes.nix](../hermes/hermes.nix)

The ranking of the answer is done by a model from [ai-models.nix](../../../../lib/ai-models.nix), which also sets the limits on candidates. When the provider refuses, the chain falls back on a fusion-only reranker: recall then ranks worse, but it does not fail

Hindsight bills through the dashboard of a separate key, `openrouter-hindsight-api-key`, which carries every model of the service, rather than by tokens: embeddings and the reranker have no counter of their own, and the catalogue price of a model arrives as zero — see `PITFALLS.md`. The key and the timer that exports the counter to Prometheus live in [monitor.nix](monitor.nix), and the reason for a separate key is in `DEVIATIONS.md`

The same timer counts the recorded calls of the rerank model, failures included, from the traces of the bank. Those records do not show how many calls were paid for or how many searches fell back on RRF. A trace lives one day, so the timer keeps the accumulated counter by day; records missed before its first run cannot be recovered

The usual set of tools is enough to search for facts, to keep them and to retire an outdated one with `invalidate_memory`. An invalidation belongs to the id of a fact: the record stays, but it leaves the usual search and the consolidation. A later audit reaches it in a separate request with the state `invalidated`; no deep reflection over such records is configured

The template of the bank declares the mental model `owner-working-brief`: a synthesised brief of the owner, with the active projects, the systems and the services, the steady preferences, the decisions taken, the exact paths and commands, and the open work. It recalculates itself on a schedule from [service.nix](service.nix), which also holds the query the model assembles it from; the client has no schedule of its own

The brief is read by id with `get_mental_model`, which is on the allowlist of the service and therefore reachable over MCP, without a shell and without a token in the command. The tools that create, recalculate and delete a mental model stay off the allowlist: the model declares a template, never a client. The answer carries `last_refreshed_at`, when the last recalculation finished, and `is_stale`, whether memories arrived in the area of the model after it, that is, whether the next recalculation would rewrite it

The choice of tools on the client does not replace the authorisation: the holder of the token reaches the other operations the server allows

## Before the first activation

- The owner creates the subvolumes that [the disk configuration of the station](../../../station/disko.nix) declares, on an existing Btrfs volume; creating the service needs no formatting and no repartitioning
- PostgreSQL must see the mounted storage rather than an empty directory on the root file system. The checks at the start demand the mountpoint and the Btrfs subvolume, and an existing cluster can never be replaced or initialised over
- The cluster must be UTF-8. A preparatory service creates pgvector as PostgreSQL before the unprivileged application starts
- The secrets of the server and of the clients must decrypt, and the OpenRouter key must carry the right limits on models, hosts and privacy
- The key `openrouter-hindsight-api-key` must allow the models of [ai-models.nix](../../../../lib/ai-models.nix) and their hosts. The reranker of MongoDB is unreachable with mandatory ZDR: its requests depend on the policy of OpenRouter rather than on the settings of the embeddings
- Before the server is updated, the limits on the requests of the embeddings and of the reranker must be enforced by the policy of OpenRouter rather than by the settings of a chat request; where that support stands and how to check the update are in [WORKAROUNDS.md](../../../../WORKAROUNDS.md)
- The owner activates it. Afterwards the health of the services, the refusal of the API without a token, both clients and the first successful backup need a check; a local trial proves nothing about the reachability of the station

## Backup and restore

[backup.nix](backup.nix) takes a consistent dump of PostgreSQL, snapshots the finished dumps with Btrfs and adds them to the existing restic backup of the station. The live directory of PostgreSQL is never used in place of a logical backup. The paths and the schedules are declared in the module and in the configuration of the host

To check a restore, take a finished dump from the backup directory, from a snapshot or from restic, and unpack the zstd into a private temporary directory. Check the archive with `pg_restore --list`, then create a separate empty UTF-8 database with an unprivileged owner and install pgvector in it beforehand as the administrator of PostgreSQL

Restore into that separate database with `pg_restore --exit-on-error --no-owner --no-acl --no-comments --role <owner> --dbname <check-database> <dump>`. Check the facts with Cyrillic in them, the presence of the vector data and the owner of the tables. A readable table of contents proves nothing about a complete restore by itself

Replacing the live database is a separate operation of the owner, with Hindsight stopped and a copy of the previous database saved. A check of a restore must never delete or overwrite the working cluster

Dumps, snapshots and restic on one disk help against a wrong change, but not against a failed disk. A separate place of storage outside is still needed
