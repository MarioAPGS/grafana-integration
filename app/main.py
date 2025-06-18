from pathlib import Path

import aiofiles
from fastapi import FastAPI, File, HTTPException, UploadFile

app = FastAPI(title="Grafana SQLite Uploader")

# Directory where SQLite databases will be stored so Grafana can read them
DATABASE_DIR = Path("/var/lib/grafana/sqlite_databases")
DATABASE_DIR.mkdir(parents=True, exist_ok=True)


@app.post("/database/sqlite")
async def upload_sqlite(
    name: str,
    db_file: UploadFile = File(..., description="SQLite .db file"),
):
    """
    Save an uploaded SQLite database so that Grafana can use it
    later as a data source.
    """
    filename = f"{name}.db" if not name.endswith(".db") else name
    target_path = DATABASE_DIR / filename

    if target_path.exists():
        raise HTTPException(
            status_code=409,
            detail="A database with that name already exists.",
        )

    # Stream the file to disk in 1 MiB chunks
    async with aiofiles.open(target_path, "wb") as out_file:
        while chunk := await db_file.read(1_048_576):
            await out_file.write(chunk)

    return {
        "status": "stored",
        "path": str(target_path),
        "size_bytes": target_path.stat().st_size,
    }
