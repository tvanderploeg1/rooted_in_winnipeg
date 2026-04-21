# Rooted in Winnipeg

Rails 8 e-commerce project for a Winnipeg-focused plant shop.

## Project highlights

- Bulma-based storefront UI for a consistent look across pages
- Real plant product seed data from the Perenual API
- Devise authentication, session cart, and checkout flow
- Province-based tax calculations and order snapshot integrity
- Stripe-hosted payment confirmation flow

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

Implementation note: the project keeps both `dartsass-rails` (storefront Bulma compilation) and `sassc-rails` (sprockets/engine compatibility).

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

## 5) Run with Docker

Build the image:

```bash
docker build -t rooted-in-winnipeg .
```

Run the container:

```bash
docker run --rm -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e DB_HOST=host.docker.internal \
  -e DB_USERNAME=dev \
  -e DB_PASSWORD="your_postgres_password_here" \
  -e PERENUAL_API_KEY='your_perenual_key' \
  --name rooted-in-winnipeg \
  rooted-in-winnipeg
```
Quick check (in a second terminal): `curl -I http://localhost:3000`

## Useful commands

- Run tests: `bin/rails test`
- Run focused order/payment tests: `bin/rails test test/models/order_test.rb test/integration/orders_access_test.rb test/integration/orders_payments_test.rb`
- RuboCop: `bin/rubocop`
- Brakeman: `bundle exec brakeman --no-pager`
- Bundler audit: `bin/bundler-audit`

## Quick demo test:

1. Sign up / log in with a customer account.
2. Add product(s) to cart and update quantity.
3. Go to checkout and click `Update Totals`.
4. Place order and confirm order detail page loads.
5. From order detail, start Stripe payment and verify redirect-return flow.
6. Confirm order status updates in order history.
