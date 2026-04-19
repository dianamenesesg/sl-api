from dotenv import load_dotenv

load_dotenv()

import json
import logging
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from baml_client.async_client import b
from baml_client.type_builder import TypeBuilder
from baml_client.types import Theme

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Swiss Life API",
    description="Text classification and form completion",
    version="0.1.0",
)


class ThemeSchema(BaseModel):
    title: str
    description: str


class ClassificationResult(BaseModel):
    model_reasoning: str
    chosen_theme: ThemeSchema


class ClassificationRequest(BaseModel):
    text: str
    themes: list[ThemeSchema]


class FormCompletionRequest(BaseModel):
    text: str
    json_schema: dict | None = None


def _to_fieldtype(tb: TypeBuilder, schema: dict):
    t = schema.get("type", "string")
    if t == "integer":
        return tb.int()
    if t in ("number", "float"):
        return tb.float()
    if t == "boolean":
        return tb.bool()
    if t == "array":
        return _to_fieldtype(tb, schema.get("items", {"type": "string"})).list()
    return tb.string()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/classify", response_model=ClassificationResult)
async def classify_text(payload: ClassificationRequest):
    logger.info("classify_text called")
    themes = [Theme(title=t.title, description=t.description) for t in payload.themes]
    result = await b.ClassifyText(text=payload.text, themes=themes)
    theme_map = {t.title: t for t in payload.themes}
    chosen = theme_map.get(result.chosen_theme_title)
    if chosen is None:
        logger.error("Model chose unknown theme: %r", result.chosen_theme_title)
        raise HTTPException(status_code=422, detail=f"Model chose unknown theme: {result.chosen_theme_title!r}")
    logger.info("classify_text succeeded, chosen theme: %s", chosen.title)
    return ClassificationResult(model_reasoning=result.model_reasoning, chosen_theme=chosen)


@app.post("/complete-form")
async def complete_form(payload: FormCompletionRequest):
    if payload.json_schema is None:
        logger.info("complete_form called, hardcoded schema")
        async def generator():
            stream = b.stream.ExtractCustomerInfo(text=payload.text)
            last = None
            async for partial in stream:
                last = partial
                yield f"data: {partial.model_dump_json()}\n\n"
            result = last.model_dump() if last else {}
            pi = result.get("personal_info") or {}
            result["extraction"] = "successful" if all(pi.get(f) not in (None, "null") for f in ("first_name", "last_name", "gender")) else "failed"
            yield f"data: {json.dumps(result)}\n\n"
            logger.info("complete_form stream finished, extraction=%s", result["extraction"])
        return StreamingResponse(generator(), media_type="text/event-stream")

    logger.info("complete_form called, dynamic schema")
    tb = TypeBuilder()
    properties = payload.json_schema.get("properties", {})
    required = set(payload.json_schema.get("required", []))
    for name, prop_schema in properties.items():
        ft = _to_fieldtype(tb, prop_schema)
        if name not in required:
            ft = ft.optional()
        section = prop_schema.get("section")
        if section == "personal_info":
            tb.PersonalInfo._bldr.property(name).type(ft)
        elif section == "contact_info":
            tb.ContactInfo._bldr.property(name).type(ft)
        else:
            tb.ComplementaryInfo.add_property(name, ft)

    async def generator():
        stream = b.with_options(tb=tb).stream.ExtractDynamic(text=payload.text)
        last = None
        async for partial in stream:
            last = partial
            yield f"data: {partial.model_dump_json()}\n\n"
        result = last.model_dump() if last else {}
        pi = result.get("personal_info") or {}
        result["extraction"] = "successful" if all(pi.get(f) not in (None, "null") for f in ("first_name", "last_name", "gender")) else "failed"
        yield f"data: {json.dumps(result)}\n\n"
        logger.info("complete_form stream finished, extraction=%s", result["extraction"])
    return StreamingResponse(generator(), media_type="text/event-stream")
