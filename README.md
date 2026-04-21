# Rooted in Winnipeg

Rails 8 e-commerce capstone project for a Winnipeg-focused plant shop.

## Prerequisites

- Ruby `3.3.5` (see `.ruby-version`)
- PostgreSQL running locally
- Node.js + Yarn

## 1) Configure environment variables

Create a `.env` file in the project root (or update the existing one) with:

```bash
DB_PASSWORD=your_postgres_password
PERENUAL_API_KEY=your_perenual_api_key
STRIPE_SECRET_KEY=replace_me
STRIPE_PUBLISHABLE_KEY=replace_me
```

The app can boot without Stripe keys for basic local development, but if you want to seed product data you will need a valid `PERENUAL_API_KEY` because `db/seeds.rb` fetches plant data from the Perenual API.

Stripe note:
- Checkout uses Stripe-hosted redirect confirmation (no local webhook/CLI setup required for basic payment flow).

## 2) Install dependencies

```bash
bundle install
yarn install
```

Or use the project helper script:

```bash
bin/setup --skip-server
```

## 3) Prepare the database

```bash
bin/rails db:prepare
```

If you want to load the full seed data:

```bash
bin/rails db:seed
```

## 4) Run the app

Start Rails and the CSS watcher together:

```bash
bin/dev
```

Then open [http://localhost:3000](http://localhost:3000).

## Useful commands

- Run tests: `bin/rails test`
- RuboCop: `bin/rubocop`
- Brakeman: `bin/brakeman`
- Bundler audit: `bin/bundler-audit`
