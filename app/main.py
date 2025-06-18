from pathlib import Path

import aiofiles
import httpx
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse, Response

app = FastAPI(title="Grafana SQLite Uploader")

# ─────────────────────────────────────────────────────────────
# 1) Upload form + SQLite upload
# ─────────────────────────────────────────────────────────────
DATABASE_DIR = Path("/var/lib/grafana/sqlite_databases")
DATABASE_DIR.mkdir(parents=True, exist_ok=True)


@app.get("/upload-form", response_class=HTMLResponse)
async def upload_form():
    return """
    <html>
    <head><title>Upload SQLite DB</title></head>
    <body>
        <h2>Upload SQLite Database for Grafana</h2>
        <form action="/database/sqlite" method="post" enctype="multipart/form-data">
            <label>Database Name:</label>
            <input type="text" name="name" required><br><br>
            <label>Select .db file:</label>
            <input type="file" name="db_file" accept=".db" required><br><br>
            <input type="submit" value="Upload">
        </form>
    </body>
    </html>
    """


@app.post("/database/sqlite")
async def upload_sqlite(
    name: str = Form(...),
    db_file: UploadFile = File(..., description="SQLite .db file"),
):
    filename = f"{name}.db" if not name.endswith(".db") else name
    target_path = DATABASE_DIR / filename

    if target_path.exists():
        raise HTTPException(409, "A database with that name already exists.")

    async with aiofiles.open(target_path, "wb") as out_file:
        while chunk := await db_file.read(1_048_576):
            await out_file.write(chunk)

    return {
        "status": "stored",
        "path": str(target_path),
        "size_bytes": target_path.stat().st_size,
    }
