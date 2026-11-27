# survey-relay

Cloudflare Worker behind the in-app survey. It serves the survey to show and forwards
responses to a Discord channel. The webhook URL is a Worker secret and never ships in the app.
Surveys are JSON in KV, so a new survey needs no app release.

## Deploy

```
cd workers/survey-relay
npx wrangler kv namespace create SURVEY_KV     # paste the id into wrangler.toml
npx wrangler secret put DISCORD_WEBHOOK_URL
npx wrangler secret put IP_HASH_SALT           # any long random string
npx wrangler deploy
```

Put the deployed Worker URL in `surveyEndpoint` in `app/lib/survey/survey.dart`.

## Edit surveys in the app (developers)

Set an admin token once, using a long random string you generate yourself (a password manager works):

```
npx wrangler secret put SURVEY_ADMIN_TOKEN
```

Then open Settings > Debug > Survey > Open editor, paste the same token, and create, edit, activate
or delete surveys. The token is kept in the app's local prefs on your machine only. Without the
secret every `/admin/*` route answers `404`. Wrong tokens get `401`, and 10 wrong tries per hour
per IP lock the caller out (`429`).

`/admin` routes (all need `Authorization: Bearer <token>`): `GET /admin/surveys`,
`PUT /admin/surveys/<id>`, `DELETE /admin/surveys/<id>`, `PUT /admin/active` with `{"id": "<id>"}`
or `{"id": null}`. The Worker validates every survey it stores.

## Publish a survey from the command line (no app update)

Copy `surveys/example.json`, give it a new unique `id`, then:

```
npx wrangler kv key put --binding SURVEY_KV --remote "survey:<id>" --path surveys/<file>.json
npx wrangler kv key put --binding SURVEY_KV --remote "active" "<id>"
```

Stop a survey early: `npx wrangler kv key delete --binding SURVEY_KV --remote "active"`.
Apps cache the survey for about 5 minutes. Each install sees each survey id once, so reusing an
id does not show it again; use a new id for a new survey.

### Survey format

| field | meaning |
| --- | --- |
| `id` | unique, `A-Z a-z 0-9 _ . -`, max 64 |
| `title`, `intro` | shown in the dialog; `title` is also the Discord embed title |
| `expires` | optional date; after it the survey is no longer served or accepted |
| `questions` | up to 5 |
| question `type` | `choice` (single choice, with `options`) or `text` (max 500 chars) |
| question `required` | the Send button waits for it |
| option | `id`, `label`, optional `description` |

Keep the English text plain; surveys are not translated.

## Responses

`POST /` with `content-type: application/json`:

```json
{
  "v": 2,
  "surveyId": "genai-2026-11",
  "installId": "<random uuid generated once per install>",
  "answers": { "stance": "optional_only", "comment": "optional text" },
  "appVersion": "1.6.4",
  "platform": "windows | macos | linux"
}
```

Answers are checked against the stored survey (unknown option ids are rejected). `200 {ok:true}`
(`duplicate:true` for a repeat install), `400/413/415` bad request, `404` unknown or expired
survey, `429` rate limited (10/hour per IP), `502/503` Discord failed. IPs are only used as a
salted hash for a one-hour counter.

`GET /active` returns the survey JSON, or `204` when there is none.
