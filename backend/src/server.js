import express from "express";
import helmet from "helmet";
import Database from "better-sqlite3";
import crypto from "node:crypto";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const app=express(), here=path.dirname(fileURLToPath(import.meta.url));
const dataDir=process.env.PEO_YAME_DATA_DIR||path.resolve(here,"../data");
fs.mkdirSync(dataDir,{recursive:true});
const db=new Database(path.join(dataDir,"peo-yame.sqlite"));
db.pragma("journal_mode = WAL");
db.exec("CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,name TEXT NOT NULL,phone TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,password_salt TEXT NOT NULL,created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,user_id TEXT NOT NULL,created_at TEXT NOT NULL,expires_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS readings(id INTEGER PRIMARY KEY AUTOINCREMENT,temperature REAL NOT NULL,humidity REAL NOT NULL,created_at TEXT NOT NULL,synthetic INTEGER NOT NULL DEFAULT 1);");
app.disable("x-powered-by"); app.use(helmet({contentSecurityPolicy:false})); app.use(express.json({limit:"32kb"})); app.use(express.static(path.resolve(here,"../public")));
const now=()=>new Date().toISOString(), digest=x=>crypto.createHash("sha256").update(x).digest("hex");
function phoneNumber(value){const d=String(value||"").replace(/\D/g,"");const n=d.startsWith("267")?d.slice(3):d;if(!/^\d{8}$/.test(n))throw Error("Enter an 8-digit Botswana number");return "+267"+n;}
function passwordHash(pass,salt){return crypto.scryptSync(pass,salt,64).toString("hex");}
const tokenFrom=req=>(req.get("authorization")||"").replace(/^Bearer /i,"");
function userFor(req){const t=tokenFrom(req);if(!t)return null;const u=db.prepare("SELECT users.*,sessions.expires_at FROM sessions JOIN users ON users.id=sessions.user_id WHERE token_hash=?").get(digest(t));return u&&u.expires_at>now()?u:null;}
app.get("/api/health",(_q,r)=>r.json({ok:true,authEnabled:true,time:now()}));
app.get("/api/status",(_q,r)=>r.json({online:true,lastSyncedAt:now(),reading:db.prepare("SELECT * FROM readings ORDER BY id DESC LIMIT 1").get()||null,dataLabel:"synthetic demo data"}));
app.get("/api/readings",(_q,r)=>r.json(db.prepare("SELECT * FROM readings ORDER BY id DESC LIMIT 200").all()));
app.post("/api/account/register",(q,r)=>{try{const nm=q.body?.name,ph=phoneNumber(q.body?.phone),pw=q.body?.password;if(typeof nm!=="string"||nm.trim().length<2)return r.status(400).json({error:"Enter your full name"});if(typeof pw!=="string"||pw.length<10)return r.status(400).json({error:"Password must be at least 10 characters"});const salt=crypto.randomBytes(16).toString("hex"),id=crypto.randomUUID();db.prepare("INSERT INTO users VALUES(?,?,?,?,?,?)").run(id,nm.trim(),ph,passwordHash(pw,salt),salt,now());r.status(201).json({id,name:nm.trim(),phone:ph});}catch(e){r.status(400).json({error:e.message==="Enter an 8-digit Botswana number"?e.message:"Could not create account"});}});
app.post("/api/account/login",(q,r)=>{try{const ph=phoneNumber(q.body?.phone),u=db.prepare("SELECT * FROM users WHERE phone=?").get(ph);if(!u||passwordHash(String(q.body?.password||""),u.password_salt)!==u.password_hash)return r.status(401).json({error:"Phone number or password is incorrect"});const t=crypto.randomBytes(32).toString("base64url");db.prepare("INSERT INTO sessions VALUES(?,?,?,?)").run(digest(t),u.id,now(),new Date(Date.now()+604800000).toISOString());r.json({token:t,user:{id:u.id,name:u.name,phone:u.phone}});}catch{r.status(401).json({error:"Phone number or password is incorrect"});}});
app.get("/api/account",(q,r)=>{const u=userFor(q);if(!u)return r.status(401).json({error:"Sign in to continue"});r.json({id:u.id,name:u.name,phone:u.phone});});
app.post("/api/account/logout",(q,r)=>{const t=tokenFrom(q);if(t)db.prepare("DELETE FROM sessions WHERE token_hash=?").run(digest(t));r.status(204).end();});
const port=Number(process.env.PORT||3000),host=process.env.HOST||"127.0.0.1";
app.listen(port,host,()=>console.log("Peo Yame listening on http://"+host+":"+port));
