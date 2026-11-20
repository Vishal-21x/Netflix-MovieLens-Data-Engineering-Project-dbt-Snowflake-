# MovieLens Data Engineering Project (dbt + Snowflake)

A data engineering project that builds an ELT pipeline with **dbt** on **Snowflake**. It transforms raw [MovieLens](https://grouplens.org/datasets/movielens/) data (movies, ratings, tags and genome scores) into clean, tested dimension, fact and mart tables ready for analytics.

## Data Engineering Concepts Covered

- ELT pipeline: raw data is loaded into Snowflake first, then transformed in the warehouse with dbt
- Layered modeling: staging → dimension / fact → mart
- Dimensional modeling with dimension and fact tables
- Incremental loading (`fct_ratings` only processes new rows)
- Slowly changing data tracking with snapshots
- Data quality testing: schema tests, a custom macro and a singular test
- Reusable code with Jinja macros and the `dbt_utils` package
- Seeds for small reference data


## What I Learned

1. **Layered data modeling**: I structured the pipeline into staging, dimension/fact and mart layers, so raw data is cleaned once and reused downstream instead of being reshaped in every query.
2. **Incremental loading**: I built `fct_ratings` as an incremental model that only processes rows newer than the latest `rating_timestamp`, which avoids reloading the whole table on every run.
3. **Tracking change over time**: I used a dbt snapshot with the timestamp strategy to keep the history of user tags, including handling deleted records.
4. **Data quality testing**: I combined schema tests (not null, unique, relationships) with a custom Jinja macro and a singular test, so bad data gets caught before it reaches the marts.
5. **Writing reusable, maintainable code**: I used Jinja macros, the `dbt_utils` package, seeds and ephemeral models to cut repetition and keep the SQL modular.




## Tech Stack

- **dbt Core** (`dbt-snowflake`, built with dbt 1.9.6)
- **Snowflake** as the data warehouse
- **SQL + Jinja**
- **dbt_utils** 1.3.0 ([`dbt-labs/dbt_utils`](https://github.com/dbt-labs/dbt-utils))

## Data Flow

```
MOVIELENS.RAW (source tables)
        │
        ▼
   staging  ──►  dim / fct  ──►  mart
   (src_*)       (tables)        (mart_movie_releases)
```

Raw tables read from `MOVIELENS.RAW`: `raw_movies`, `raw_ratings`, `raw_tags`, `raw_genome_tags`, `raw_genome_scores`, `raw_links`.

## Models

| Layer | Model | Materialization | What it does |
|---|---|---|---|
| Staging | `src_movies`, `src_links`, `src_genome_score`, `src_genome_tags` | view | Renames columns from the raw tables to snake_case (e.g. `movieId` → `movie_id`) |
| Staging | `src_ratings`, `src_tags` | table | Same renaming, and converts epoch timestamps with `TO_TIMESTAMP_LTZ` |
| Dimension | `dim_movies` | table | Cleans movie titles (`INITCAP(TRIM(...))`) and splits `genres` into a `genre_array` |
| Dimension | `dim_genome_tags` | table | Cleans tag names for the genome tag lookup |
| Dimension | `dim_users` | table | Unique users taken from both ratings and tags |
| Dimension | `dim_movies_with_tags` | ephemeral | Joins movies with their genome tags and relevance scores |
| Fact | `fct_ratings` | incremental | User ratings, with null ratings removed. Incremental runs only add rows newer than the latest `rating_timestamp` |
| Fact | `fct_genome_scores` | table | Genome relevance scores, rounded to 4 decimals, keeping only scores above 0 |
| Fact | `ep_movie_with_tags` | table | Movie-with-tags fact built from the ephemeral `dim_movies_with_tags` |
| Mart | `mart_movie_releases` | table | Ratings joined to the release dates seed, with a `release_info_available` flag (`known` / `unknown`) |

## Other Project Components

- **Seed**: `seed_movie_release_dates.csv` holds movie release dates (`movie_id`, `release_date`).
- **Snapshot**: `snap_tags` tracks changes to user tags over time, using the `timestamp` strategy on `tag_timestamp` with `invalidate_hard_deletes` enabled. It writes to the `snapshots` schema.
- **Custom macro**: `no_nulls_in_columns(model)` returns every row of a model that has a NULL in any column.
- **Singular test**: `relevence_score_test.sql` uses that macro to check that `fct_genome_scores` has no NULLs.
- **Schema tests**: `not_null` on key columns, `unique` on `dim_users.user_id` and `dim_genome_tags.tag_id`, and a `relationships` test from `fct_ratings.movie_id` to `dim_movies.movie_id`.
- **Analysis**: `movie_analysis.sql` lists the top 20 highest-rated movies that have more than 100 ratings.

## Project Structure

```
netflix/
├── analyses/
│   └── movie_analysis.sql
├── macros/
│   └── no_nulls_in_columns.sql
├── models/
│   ├── staging/        # src_* models
│   ├── dim/            # dimension tables
│   ├── fct/            # fact tables
│   └── mart/           # reporting-ready tables
├── seeds/
│   └── seed_movie_release_dates.csv
├── snapshots/
│   └── snap_tags.sql
├── tests/
│   └── relevence_score_test.sql
├── dbt_project.yml
└── packages.yml
```

## Getting Started

### Prerequisites

- Python 3.8+
- A Snowflake account with the MovieLens data loaded into `MOVIELENS.RAW`

### Setup

```bash
# Install dbt with the Snowflake adapter
pip install dbt-snowflake

# Install dbt packages (dbt_utils)
dbt deps
```

Add a `netflix` profile to your `~/.dbt/profiles.yml` with your own Snowflake credentials (account, user, role, warehouse, database `MOVIELENS`, schema `DEV`).

### Run the project

```bash
dbt seed        # load the release dates seed
dbt run         # build all models
dbt snapshot    # run the tags snapshot
dbt test        # run schema and singular tests
dbt docs generate && dbt docs serve   # browse the docs and lineage graph
```
