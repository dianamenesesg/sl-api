# Swiss Life API

A FastAPI service that provides text classification and customer information extraction. Built on [BAML](https://docs.boundaryml.com/) for structured LLM output and [Nebius AI](https://nebius.com/) as the inference provider.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Setup](#setup)
- [Running the Server](#running-the-server)
- [API Reference](#api-reference)
  - [GET /health](#get-health)
  - [POST /classify](#post-classify)
  - [POST /complete-form](#post-complete-form)
    - [Hardcoded Schema Mode](#hardcoded-schema-mode)
    - [Dynamic Schema Mode](#dynamic-schema-mode)
- [LLM Models](#llm-models)
- [Cost Scaling](#cost-scaling)
- [Streaming Response Format](#streaming-response-format)

---

## Architecture Overview

```
Client
  │
  ▼
FastAPI (app/main.py)
  │
  ├── POST /classify ──────────► BAML ClassifyText ──────► ClassificationClient (Llama 3.1 8B)
  │
  └── POST /complete-form
        ├── (no dynamic json_schema) ──► BAML ExtractCustomerInfo ► ExtractionClient (Gemma 2 2B)
        └── (with dynamic json_schema) ► BAML ExtractDynamic ──────► ExtractionClient (Gemma 2 2B)
```

BAML takes care of building prompts, communicating with the LLM, and parsing typed responses. The API layer converts HTTP requests into BAML calls and returns structured results to the client.

---

## Setup

**Prerequisites:** Python 3.11+ and [uv](https://docs.astral.sh/uv/getting-started/installation/)

1. Clone the repository and install dependencies:
   ```bash
   uv sync
   ```

2. Configure environment variables — copy `.env.example` to `.env` and fill in your key:
   ```bash
   cp .env.example .env
   ```
   ```
   NEBIUS_API_KEY=your_nebius_api_key_here
   ```

---

## Running the Server

```bash
uv run uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`. Interactive docs are at `http://localhost:8000/docs`.

---

## API Reference

### GET /health

Simple liveness check.

**Response**
```json
{ "status": "ok" }
```

---

### POST /classify

Classifies a piece of text into exactly one of the provided themes. The LLM reasons step-by-step and selects the best-matching theme.

**How theme selection works**

The LLM does **not** return the theme object directly. Instead, the process is:

1. The caller sends a list of themes (each with a `title` and `description`).
2. The LLM receives all theme titles and descriptions in its prompt and is instructed to output only the `title` string of the best-matching theme — nothing else.
3. The API builds a lookup map (`title → theme object`) from the original caller input.
4. The LLM's output title is used as a key to retrieve the original theme object from that map.
5. That original object is what gets returned in `chosen_theme`.

This design prevents the LLM from altering or inventing the title or description. It only returns a title string, and the API maps it back to the corresponding object from the original input. If the returned title doesn’t exactly match any provided theme, the API responds with a 422 error instead of returning a fabricated or partial result.

**Request body**

| Field    | Type                  | Required | Description                                  |
|----------|-----------------------|----------|----------------------------------------------|
| `text`   | `string`              | Yes      | The text to classify                         |
| `themes` | `array` of theme objects | Yes   | List of candidate themes to classify into    |

Each theme object:

| Field         | Type     | Required | Description                              |
|---------------|----------|----------|------------------------------------------|
| `title`       | `string` | Yes      | Unique name of the theme                 |
| `description` | `string` | Yes      | What this theme represents               |

**Example request**

```bash
curl -X 'POST' \
  'http://localhost:8000/classify' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "I am calling because I have a problem with my internet connection",
    "themes": [
        {
            "title": "Technical support",
            "description": "The customer is calling for technical support"
        },
        {
            "title": "Billing",
            "description": "The customer is calling for billing issues"
        },
        {
            "title": "Refund",
            "description": "The customer is calling for a refund"
        }
    ]
}'
```

**Response body**

| Field             | Type     | Description                                               |
|-------------------|----------|-----------------------------------------------------------|
| `model_reasoning` | `string` | Step-by-step explanation of why the theme was selected    |
| `chosen_theme`    | `object` | The selected theme (includes both `title` and `description`) |

**Example response**

```json
{
  "model_reasoning": "The customer is describing a problem with their internet connection, which suggests a technical issue. This matches the description of technical support, which involves resolving customer technical problems.",
  "chosen_theme": {
    "title": "Technical support",
    "description": "The customer is calling for technical support"
  }
}
```

**Error responses**

| Status | Condition |
|--------|-----------|
| `422`  | The model chose a theme title that does not match any of the provided themes |

---

### POST /complete-form

Extracts structured customer information from a conversation transcript and streams partial results as they are generated by the LLM. The endpoint supports two modes depending on whether a `json_schema` is provided.

The response is a streaming SSE (Server-Sent Events) response (`Content-Type: text/event-stream`). Each event has the format:

```
data: {...}\n\n
```

Intermediate events contain partial data as the LLM generates tokens. The final event contains the complete extracted data plus an `"extraction"` status field.

**Request body**

| Field        | Type     | Required | Description                                                                 |
|--------------|----------|----------|-----------------------------------------------------------------------------|
| `text`       | `string` | Yes      | The conversation transcript to extract information from                     |
| `json_schema`| `object` | No       | JSON Schema describing additional fields to extract. If omitted, uses the hardcoded schema. |

---

#### Hardcoded Schema Mode

When `json_schema` is not provided, the API uses a fixed schema (`CustomerForm`) defined in `baml_src/form_completion.baml`.

**Fixed output structure**

```
CustomerForm
├── personal_info (PersonalInfo)
│   ├── first_name    string       — required
│   ├── last_name     string       — required
│   └── gender        Gender       — required (Male | Female | Other | Refused)
└── contact_info (ContactInfo)
    ├── email                    string?          — optional
    ├── phone                    string?          — optional
    ├── preferred_contact_method ContactMethod?   — optional (Email | Phone)
    └── call_reasons             string[]?        — optional
```

**Example request**

```bash
curl -X 'POST' \
  'http://localhost:8000/complete-form' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
 "text": "Agent: Good morning! Thank you for reaching out. I’ll need to collect some basic details to assist you better. Could you please provide your first and last name? Customer: Sure! My name is John Doe. Agent: Thank you, John. May I also ask for your gender? Customer: I'\''d prefer not to share that at the moment. Agent: No problem at all. Now, for contact purposes, could you share your email address? Customer: Yes, my email is johndoe@example.com. Agent: Great! Do you have a phone number where we can reach you? Customer: I’d rather not provide that right now. Agent: That’s completely fine. How would you prefer us to contact you—by email or phone? Customer: Please contact me via Email. Agent: Understood! Lastly, can you share the reason for your call today? Customer: I’m not ready to specify that just yet. Agent: That’s okay, John! I’ve noted everything down. If you need any further assistance, feel free to reach out. Have a great day!"
}'
```

**Example stream output**

Intermediate events (partial data as tokens arrive):
```
data: {"personal_info":{"first_name":null,"last_name":null,"gender":null},"contact_info":null}

data: {"personal_info":{"first_name":"John","last_name":"Doe","gender":"Refused"},"contact_info":{"email":"johndoe@","phone":null,"preferred_contact_method":null,"call_reasons":null}}

data: {"personal_info":{"first_name":"John","last_name":"Doe","gender":"Refused"},"contact_info":{"email":"johndoe@example.com","phone":null,"preferred_contact_method":null,"call_reasons":null}}

data: {"personal_info":{"first_name":"John","last_name":"Doe","gender":"Refused"},"contact_info":{"email":"johndoe@example.com","phone":null,"preferred_contact_method":"Email","call_reasons":null}}

data: {"personal_info":{"first_name":"John","last_name":"Doe","gender":"Refused"},"contact_info":{"email":"johndoe@example.com","phone":null,"preferred_contact_method":"Email","call_reasons":null}}
```

Final event (complete data + extraction status):
```
data: {"personal_info": {"first_name": "John", "last_name": "Doe", "gender": "Refused"}, "contact_info": {"email": "johndoe@example.com", "phone": null, "preferred_contact_method": "Email", "call_reasons": null}, "extraction": "successful"}
```

---

#### Dynamic Schema Mode

When `json_schema` is provided, the API dynamically extends the extraction schema at runtime using BAML's TypeBuilder. This allows the caller to define custom fields to extract beyond the fixed `PersonalInfo` and `ContactInfo` structure.

**`json_schema` format**

The schema follows a subset of JSON Schema, with an extra `"section"` keyword on each property to control where the field is placed in the output:

| `"section"` value   | Output location                 |
|---------------------|---------------------------------|
| `"personal_info"`   | Merged into `personal_info`     |
| `"contact_info"`    | Merged into `contact_info`      |
| *(any other value)* | Placed in `complementary_info`  |

Supported property types: `string` (default), `integer`, `number`/`float`, `boolean`, `array`.


**Example request**

```bash
curl -X POST http://localhost:8000/complete-form \
  -H "Content-Type: application/json" \
  -d '{
      "text": "I'm Jane Smith, Im non-binary. Dont call me. My address is P. Sherman 42 Wallaby, I am ten years old. and I like swimming",
      "json_schema": {
        "properties": {
          "age": { "type": "integer", "section": "personal_info" },
          "work_phone": { "type": "string", "section": "contact_info" },
          "hobbies": { "type": "string" }
        }
      }
  }'
```

**Output structure**

```
DynamicOutput
├── personal_info       — always present (fields defined via "section": "personal_info")
├── contact_info        — always present (fields defined via "section": "contact_info")
└── complementary_info  — present when extra fields are defined (all other sections)
```

**Example final event**

```
data: {"personal_info": {"first_name": "Jane", "last_name": "Smith", "gender": "Other", "age": 10}, "contact_info": {"email": null, "phone": null, "preferred_contact_method": null, "call_reasons": null, "work_phone": null}, "complementary_info": {"hobbies": "swimming"}, "extraction": "successful"}
```

---

#### Extraction status field

The final SSE event of every `/complete-form` response includes an `"extraction"` key:

| Value          | Condition                                                                                      |
|----------------|-----------------------------------------------------------------------------------------------|
| `"successful"` | All three required `personal_info` fields (`first_name`, `last_name`, `gender`) are present and non-null |
| `"failed"`     | At least one of the three required fields is missing or null                                   |

---

## LLM Models

| Client               | Model                                   | Used for         | Temperature | Notes                        |
|----------------------|-----------------------------------------|------------------|-------------|------------------------------|
| `ClassificationClient` | `meta-llama/Meta-Llama-3.1-8B-Instruct` | `/classify`    | `0`         | Deterministic — one correct theme |
| `ExtractionClient`   | `google/gemma-2-2b-it`                  | `/complete-form` | default     | Allows natural phrasing in extracted values |

Both models are served via the [Nebius AI](https://nebius.com/) OpenAI-compatible API (`https://api.tokenfactory.nebius.com/v1/`).

**Why `temperature: 0` for classification?**

Temperature controls how much randomness the model uses when choosing the next token. At temperature: 0, it always selects the most likely option, so the output is consistent for the same input.

This is used for the `ClassificationClient` because classification has a single correct answer within a fixed set of themes. Given that the same text should always map to the same theme, and the output is also constrained by a lookup step, where the returned title must exactly match one of the input themes, the the model behaves in a deterministic way, reducing the risk of borderline cases switching between themes.

For the `ExtractionClient`, the default temperature is kept. The fields being extracted are factual (name, phone, email), so the model is already unlikely to vary significantly.

---

## Cost Scaling

Each request makes exactly **1 LLM call**. Cost depends on input and output token counts. Token count ≈ words × 1.3. BAML adds extra input tokens for system instructions and output format — not accounted for below; measure with real traces.

Pricing used: **$0.02 / 1M input tokens**, **$0.06 / 1M output tokens** — 1 000 calls/day per route.

| Route | Input words | Input tokens | Output words | Output tokens | Cost/call | Daily | Monthly |
|---|---|---|---|---|---|---|---|
| `/classify` | 50 | 65 | 50 | 65 | $0.0000052 | $0.0052 | $0.16 |
| `/complete-form` | 170 | 221 | 30 | 39 | $0.0000068 | $0.0068 | $0.20 |
| **Combined** | | | | | | **$0.012** | **$0.36** |

---
