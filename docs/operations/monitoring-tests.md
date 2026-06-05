
# Tests de Validation — Stack de Monitoring (S1 & S2)

> **Version** : 1.0
> **Dernière mise à jour** : 2026-05-22
> **Objectif** : Générer du trafic réaliste sur S1 et S2 pour valider la collecte des métriques, logs et traces dans Grafana, Prometheus, Loki et Tempo.

---

## Prérequis

- Stack de monitoring démarrée (MonSrv, S1, S2)
- Accès SSH aux serveurs S1 et S2
- Outil `stress` installé sur S1 et S2 : `apt install -y stress`

---

## Tests sur S1 — 192.168.50.11 (Apache · MySQL)

### Stress CPU

```bash
# Stress léger (2 cores, 60s)
stress --cpu 2 --timeout 60

# Stress intense (4 cores, 120s)
stress --cpu 4 --timeout 120
```

### Stress RAM

```bash
# 2 workers × 1GB RAM, 120s
stress --vm 2 --vm-bytes 1G --timeout 120
```

### Trafic Apache

```bash
# Trafic basique — 30 requêtes
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done

# Trafic intense — 50 requêtes
for i in {1..50}; do curl -s http://localhost:8080/ > /dev/null; done

# Générer des erreurs 404 — 20 requêtes
for i in {1..20}; do curl -s http://localhost:8080/notfound > /dev/null; done

# Trafic mixte (200 + 404)
for i in {1..50}; do curl -s http://localhost:8080/ > /dev/null; done
for i in {1..20}; do curl -s http://localhost:8080/notfound > /dev/null; done
curl http://localhost:8080/nonexistent
curl http://localhost:8080/fakepage
```

### SSH

```bash
# Connexion réussie (génère un log "Accepted")
ssh ayoub@localhost

# Générer des échecs (mauvais mot de passe — exécuter depuis un autre terminal)
ssh wronguser@localhost
ssh ayoub@localhost  # entrer un mauvais mot de passe
```

### Activité MySQL

```bash
# Opérations DB basiques (CREATE, INSERT, SELECT)
docker exec -it mysql mysql -uroot -p<REDACTED> -e "
  CREATE DATABASE IF NOT EXISTS testdb;
  USE testdb;
  CREATE TABLE IF NOT EXISTS users (id INT, name VARCHAR(50));
  INSERT INTO users VALUES (1,'alice'),(2,'bob'),(3,'charlie');
  SELECT * FROM users;
  SELECT COUNT(*) FROM users;
"

# Opérations étendues (UPDATE, SELECT filtré)
docker exec -it mysql mysql -uroot -p<REDACTED> -e "
  USE testdb;
  UPDATE users SET name='dave' WHERE id=1;
  SELECT * FROM users WHERE id=1;
  SELECT * FROM users;
  SELECT COUNT(*) FROM users;
"

# Nettoyage
docker exec -it mysql mysql -uroot -p<REDACTED> -e "DROP DATABASE IF EXISTS testdb;"
```

### Génération d'erreurs (pour Loki)

```bash
# Erreurs Apache 404 et tentatives de traversal
for i in {1..10}; do
  curl -s http://localhost:8080/nonexistent$i
  curl -s http://localhost:8080/../../../etc/passwd
done

# Erreurs MySQL (mauvais mots de passe)
for i in {1..5}; do
  docker exec mysql mysql -u root -pwrong 2>/dev/null
  docker exec mysql mysql -u hacker -phack 2>/dev/null
done
```

---

## Tests sur S2 — 192.168.50.12 (Nginx · Redis)

### Stress CPU

```bash
stress --cpu 4 --timeout 120
```

### Stress RAM

```bash
stress --vm 2 --vm-bytes 1G --timeout 120
```

### Trafic Nginx

```bash
# Trafic basique — 30 requêtes
for i in {1..30}; do curl -s http://localhost/ > /dev/null; done

# Trafic intense — 50 requêtes
for i in {1..50}; do curl -s http://localhost/ > /dev/null; done

# Générer des erreurs 404
for i in {1..20}; do curl -s http://localhost/notfound > /dev/null; done

# Trafic mixte (200 + 404)
for i in {1..50}; do curl -s http://localhost/ > /dev/null; done
for i in {1..20}; do curl -s http://localhost/notfound > /dev/null; done
curl http://localhost/nonexistent
curl http://localhost/fakepage
```

### SSH

```bash
# Connexion réussie
ssh ayoub@localhost

# Tentatives échouées
ssh wronguser@localhost
```

### Activité Redis

```bash
# Opérations SET/GET basiques
docker exec -it redis redis-cli SET testkey "hello"
docker exec -it redis redis-cli GET testkey
docker exec -it redis redis-cli SET counter 0

# Incrémenter un compteur (génère de l'activité)
for i in {1..50}; do docker exec -it redis redis-cli INCR counter > /dev/null; done

# Bulk SET pour générer de l'utilisation mémoire
for i in {1..100}; do
  docker exec -it redis redis-cli SET "key:$i" "value-$i" > /dev/null
done

# Générer des hits (clés existantes)
for i in {1..50}; do
  docker exec -it redis redis-cli GET "key:$i" > /dev/null
done

# Générer des misses (clés inexistantes)
for i in {1..20}; do
  docker exec -it redis redis-cli GET "missing:$i" > /dev/null
done

# Lister toutes les clés
docker exec -it redis redis-cli KEYS "*"

# Vérifier les stats Redis
docker exec -it redis redis-cli INFO stats | grep -E "hits|misses|commands"

# Nettoyage
docker exec -it redis redis-cli FLUSHALL
```

### Génération d'erreurs (pour Loki)

```bash
# Erreurs Nginx 404
for i in {1..10}; do
  curl -s http://localhost/nonexistent$i
  curl -s http://localhost/admin
  curl -s http://localhost/../etc/passwd
done

# Erreurs Redis (mauvais mot de passe)
for i in {1..5}; do
  docker exec redis redis-cli -a wrongpassword ping 2>/dev/null
done
```

---

## Test Rapide Complet

### S1 — Tout-en-un

```bash
stress --cpu 4 --timeout 60 &
for i in {1..50}; do curl -s http://localhost:8080/ > /dev/null; done
for i in {1..20}; do curl -s http://localhost:8080/notfound > /dev/null; done
docker exec -it mysql mysql -uroot -p<REDACTED> -e "
  CREATE DATABASE IF NOT EXISTS testdb;
  USE testdb;
  CREATE TABLE IF NOT EXISTS t (id INT);
  INSERT INTO t VALUES (1),(2),(3);
  SELECT * FROM t;
"
```

### S2 — Tout-en-un

```bash
stress --cpu 4 --timeout 60 &
for i in {1..50}; do curl -s http://localhost/ > /dev/null; done
for i in {1..20}; do curl -s http://localhost/notfound > /dev/null; done
for i in {1..100}; do docker exec -it redis redis-cli INCR testcounter > /dev/null; done
for i in {1..50}; do docker exec -it redis redis-cli GET "missing:$i" > /dev/null; done
```

---

## Vérification dans Grafana

Après avoir exécuté les tests, vérifier les dashboards suivants :

| Dashboard | URL | Ce qu'il faut observer |
|-----------|-----|------------------------|
| Overview | `http://192.168.50.12/grafana/` | Pics de CPU/RAM pendant les tests de stress |
| Logs S1 | `http://192.168.50.12/grafana/` | Logs Apache, MySQL, SSH avec les erreurs générées |
| Logs S2 | `http://192.168.50.12/grafana/` | Logs Nginx avec erreurs 404, logs Redis |
| Traces | `http://192.168.50.12/grafana/` | Traces Apache et MySQL visibles |
| Redis | `http://192.168.50.12/grafana/` | Hits/misses, commandes/sec, mémoire utilisée |

### Requêtes Loki pour validation rapide

```logql
# Erreurs Apache 404 sur S1
{job="apache", hostname="server1"} |= "404"

# Erreurs MySQL sur S1
{job="mysql", hostname="server1"} |= "ERROR"

# Erreurs Nginx 404 sur S2
{job="nginx", hostname="server2"} |= "404"

# Tentatives SSH échouées sur S1
{job="ssh", hostname="server1"} |= "Failed password"
```

### Vérification des traces Tempo

```bash
curl -s "http://192.168.50.10:3200/api/search?limit=5" | python3 -m json.tool | grep "rootServiceName"
# Attendu : "rootServiceName": "apache" et "rootServiceName": "mysql"
```

---

## Dépannage

### Aucun log dans Loki

```bash
# Vérifier qu'Alloy tourne
ssh ayoub@192.168.50.11 "docker ps | grep alloy"
ssh ayoub@192.168.50.12 "docker ps | grep alloy"

# Redémarrer Alloy
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose restart alloy"
ssh ayoub@192.168.50.12 "cd ~/s2-monitoring && docker compose restart alloy"

# Forcer un flush en générant du trafic
ssh ayoub@192.168.50.11 "for i in {1..20}; do curl -s http://localhost:8080/ > /dev/null; done"
```

### Aucune trace dans Tempo

```bash
# Vérifier l'OTel Collector
ssh ayoub@192.168.50.11 "docker logs otel-collector --tail=10 | grep -E 'error|warn'"

# Vérifier que Tempo est accessible
curl -s http://192.168.50.10:3200/ready
```

### Prometheus targets DOWN

```bash
curl -s http://192.168.50.11:9100/metrics | head -3   # S1
curl -s http://192.168.50.12:9100/metrics | head -3   # S2
curl -s http://192.168.50.12:9121/metrics | head -3   # Redis
curl -s http://192.168.20.11:9100/metrics | head -3   # pve1
```


