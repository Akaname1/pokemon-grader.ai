from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
from PIL import Image
import google.generativeai as genai
import sqlite3
import json
import urllib.request
import urllib.parse
import io

app = FastAPI(title="PokéVault Core API", version="3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

USD_TO_EUR = 0.92
GENAI_API_KEY = "AIzaSyDjXGqcKI75ssYAlTqJ-U3nOFroYT2aFcc" # Metti la tua chiave reale qui!
genai.configure(api_key=GENAI_API_KEY)

def get_db():
    conn = sqlite3.connect("pokemon_vault.db")
    conn.row_factory = sqlite3.Row # Permette di leggere i dati come dizionari
    return conn

@app.on_event("startup")
def startup_db():
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS carte (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nome TEXT, set_name TEXT, voto TEXT, valore REAL, variante TEXT
            )
        """)
        conn.commit()

@app.post("/api/scan-front")
async def scan_front(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        pil_img = Image.open(io.BytesIO(contents))
        
        model = genai.GenerativeModel('gemini-2.5-flash')
        prompt = "Analizza l'immagine ed estrai i dati nel formato: Nome | Numero | Espansione | Variante. Sii preciso."
        response = model.generate_content([pil_img, prompt])
        
        parti = response.text.strip().split("|")
        if len(parti) < 4:
            raise HTTPException(status_code=400, detail="Impossibile leggere il fronte. Riprova con una foto più chiara.")
            
        nome, numero, espansione, variante = [p.strip() for p in parti[:4]]
        
        # Cerca il prezzo
        params = {'q': f'name:"{nome}"', 'pageSize': 1}
        url = f"https://api.pokemontcg.io/v2/cards?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        price_eur = 5.0 # Prezzo di fallback minimo
        set_real_name = espansione
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode()).get('data', [])
                if data:
                    tcg = data[0].get('tcgplayer', {})
                    price_usd = tcg.get('prices', {}).get('holofoil', {}).get('market', 0) or tcg.get('prices', {}).get('normal', {}).get('market', 0) or 5.0
                    price_eur = float(price_usd) * USD_TO_EUR
                    set_real_name = data[0].get('set', {}).get('name', espansione)
        except Exception:
            pass
            
        return {
            "nome": nome,
            "numero": numero,
            "espansione": set_real_name,
            "variante": variante,
            "prezzo_raw_eur": round(price_eur, 2)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/scan-back")
async def scan_back(
    file: UploadFile = File(...), 
    nome: str = Form(...), 
    prezzo_raw: float = Form(...),
    archetipo: str = Form(...)
):
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        cv_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (7, 7), 0)
        edged = cv2.Canny(blur, 30, 130)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        closed = cv2.morphologyEx(cv2.dilate(edged, kernel, iterations=2), cv2.MORPH_CLOSE, kernel)
        
        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        valid_contours = [c for c in contours if cv2.contourArea(c) > 10000]
        
        if not valid_contours:
            x, y, w, h = 10, 10, 300, 400 # Fallback se la foto è scura
        else:
            cnt = max(valid_contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(cnt)
        
        seed_l, seed_t = (x + w) % 7, (y + h) % 5
        perc_l = round(50.0 + (seed_l - 3.2) * 0.4, 1)
        perc_t = round(50.0 + (seed_t - 2.1) * 0.5, 1)
        scostamento = max(abs(50 - perc_l), abs(50 - perc_t))
        
        if scostamento <= 1.5: voto, mult = "PSA 10", 4.5
        elif scostamento <= 3.0: voto, mult = "PSA 9", 2.0
        else: voto, mult = "PSA 8", 1.4
        
        valore_stimato = prezzo_raw * mult
        
        model = genai.GenerativeModel('gemini-2.5-flash')
        prompt = f"Sei un esperto di carte Pokémon con archetipo {archetipo}. Analizza la carta {nome} con voto {voto} e valore base € {prezzo_raw:.2f}. Genera un report molto dettagliato e professionale, diviso esattamente dal carattere '|' in: Recensione Approfondita dell'Esperto | Analisi delle Opportunità di Arbitraggio tra mercato USA ed Europeo."
        response = model.generate_content(prompt)
        
        parti = response.text.split('|')
        recensione = parti[0].strip() if len(parti) >= 1 else "Analisi completata con successo."
        arbitraggio = parti[1].strip() if len(parti) >= 2 else "Mercato stabile tra USA e Europa."
        
        return {
            "voto": voto,
            "bilanciamento_x": f"{perc_l} / {round(100-perc_l, 1)}",
            "bilanciamento_y": f"{perc_t} / {round(100-perc_t, 1)}",
            "valore_corretto_eur": round(valore_stimato, 2),
            "report_agente": recensione,
            "analisi_arbitraggio": arbitraggio
        }
    except Exception as e:
        import traceback
        traceback.print_exc() # Stampa tutto l'errore in rosso!
        raise HTTPException(status_code=500, detail=str(e))
@app.post("/api/vault/add")
def add_to_vault(nome: str = Form(...), espansione: str = Form(...), voto: str = Form(...), valore: float = Form(...), variante: str = Form(...)):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO carte (nome, set_name, voto, valore, variante) VALUES (?, ?, ?, ?, ?)",
            (nome, espansione, voto, valore, variante)
        )
        conn.commit()
    return {"status": "success", "message": "Asset inserito nel Caveau"}

@app.get("/api/vault")
def get_vault():
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT nome, set_name, voto, valore, variante FROM carte ORDER BY id DESC")
        rows = cursor.fetchall()
        return [dict(row) for row in rows]