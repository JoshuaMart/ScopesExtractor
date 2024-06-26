## Usage

```
cp .env.example .env
docker build . -t scopes
docker run --mount type=bind,source="$(pwd)",target=/app scopes
```