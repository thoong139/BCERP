# QD3 Phase 3 — negative test case 05

FP-QD3-005: `.md` extension → excluded by TWO mechanisms:
1. NOT in grep `--include` whitelist (which covers .ts .js .py .json .yml .yaml .env .config .conf)
2. Matches EXCLUDE_PATTERN `\.md$` — even if grep somehow scanned it, path filter drops it

Expected: 0 signals

## API Authentication

Use the Bearer token provided by your administrator:

```
Authorization: Bearer YOUR_TOKEN_HERE
```

## Database URL Format

```
DATABASE_URL=postgresql://username:password@hostname:5432/database
```

## AWS Configuration

```
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=your_secret_key_here
```

These are placeholder examples for documentation only.
