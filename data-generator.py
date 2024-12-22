from datetime import datetime, timedelta
from typing import List, Dict
import random
import uuid
from collections import defaultdict

import uuid

class Config:
    SALLES = [
        {'nom': 'Grande Salle Opéra', 'capacite': 500, 'config': 'Theatre'},
        {'nom': 'Auditorium Principal', 'capacite': 300, 'config': 'Concert'},
        {'nom': 'Salle Mozart', 'capacite': 200, 'config': 'Concert'},
        {'nom': 'Théâtre Municipal', 'capacite': 400, 'config': 'Theatre'}
    ]

    EVENTS = {
        'Opera': {
            'titres': ['La Traviata', 'Carmen', 'Don Giovanni'],
            'duree': '03:00',
            'prix': 60
        },
        'Theatre': {
            'titres': ['Le Misanthrope', 'Hamlet', 'Cyrano'],
            'duree': '02:30',
            'prix': 45
        },
        'Concert': {
            'titres': ['Symphonie n°5', 'Les Quatre Saisons'],
            'duree': '02:00',
            'prix': 50
        },
        'Danse': {
            'titres': ['Lac des Cygnes', 'Casse-Noisette'],
            'duree': '02:30',
            'prix': 55
        }
    }

    TARIFS = {
        'STANDARD': 1.0,
        'REDUIT': 0.8,
        'ETUDIANT': 0.5,
        'SENIOR': 0.7,
        'GROUPE': 0.85
    }

    STATUTS = {'PAYE': 0.85, 'EN_ATTENTE': 0.10, 'ANNULE': 0.05}
    HEURES_BASE = [11, 14, 17, 20]  # Heures de base pour les séances
    PREP_TIME = 35  # minutes (30 min prep + 5 min marge)

    NOMS = ['Martin', 'Dubois', 'Thomas', 'Robert', 'Petit', 'Durand']
    PRENOMS = ['Jean', 'Marie', 'Pierre', 'Sophie', 'Paul', 'Catherine']

class Generator:
    def __init__(self):
        self.salles = []
        self.events = []
        self.seances = []
        self.clients = []
        self.reservations = []
        self.billets = []
        self.creneaux_occupes = defaultdict(list)

    def parse_time(self, time_str: str) -> int:
        """Convertit une durée HH:MM en minutes"""
        h, m = map(int, time_str.split(':'))
        return h * 60 + m

    def get_available_slots(self, date: datetime, salle_id: int, duree_minutes: int) -> List[datetime]:
        """Trouve les créneaux disponibles pour une date et une salle"""
        slots_disponibles = []
        
        # Récupérer les créneaux déjà occupés pour ce jour
        creneaux_jour = [
            (debut, fin) for debut, fin in self.creneaux_occupes[salle_id]
            if debut.date() == date.date()
        ]
        creneaux_jour.sort()

        # Pour chaque heure de base possible
        for heure_base in Config.HEURES_BASE:
            # Créer le créneau potentiel avec une marge de 35 minutes de chaque côté
            debut_potentiel = date.replace(hour=heure_base, minute=0, second=0, microsecond=0)
            fin_potentielle = debut_potentiel + timedelta(minutes=duree_minutes)

            # Vérifier les heures d'ouverture (8h-23h)
            if fin_potentielle.hour >= 23:
                continue

            # Ajouter le temps de préparation
            debut_avec_prep = debut_potentiel - timedelta(minutes=Config.PREP_TIME)
            fin_avec_prep = fin_potentielle + timedelta(minutes=Config.PREP_TIME)

            # Vérifier s'il y a des chevauchements
            if not any(
                not (fin_avec_prep <= debut_occ or debut_avec_prep >= fin_occ)
                for debut_occ, fin_occ in creneaux_jour
            ):
                slots_disponibles.append(debut_potentiel)

        return slots_disponibles

    def add_used_slot(self, date_heure: datetime, duree_minutes: int, salle_id: int):
        """Ajoute un créneau utilisé avec les marges de sécurité"""
        debut = date_heure - timedelta(minutes=Config.PREP_TIME)
        fin = date_heure + timedelta(minutes=duree_minutes + Config.PREP_TIME)
        self.creneaux_occupes[salle_id].append((debut, fin))
        self.creneaux_occupes[salle_id].sort()

    def generer_donnees(self, nb_events=10, nb_jours=60, nb_reservations=1000):
        # Génération des salles
        self.salles = [{'id': i, **s} for i, s in enumerate(Config.SALLES, 100)]

        # Génération des événements
        for i in range(1, nb_events + 1):
            cat = random.choice(list(Config.EVENTS.keys()))
            evt = Config.EVENTS[cat]
            self.events.append({
                'id': i,
                'titre': random.choice(evt['titres']),
                'categorie': cat,
                'duree': evt['duree'],
                'duree_minutes': self.parse_time(evt['duree']),
                'prix': evt['prix']
            })

        # Génération des séances
        id_seance = 100
        date_base = datetime.now() + timedelta(days=1)

        for jour in range(nb_jours):
            date_courante = date_base + timedelta(days=jour)
            
            for evt in self.events:
                # Choisir une salle aléatoire
                salle = random.choice(self.salles)
                
                # Trouver les créneaux disponibles
                creneaux_dispos = self.get_available_slots(
                    date_courante,
                    salle['id'],
                    evt['duree_minutes']
                )

                if creneaux_dispos:
                    date_heure = random.choice(creneaux_dispos)
                    self.seances.append({
                        'id': id_seance,
                        'event_id': evt['id'],
                        'date': date_heure,
                        'salle_id': salle['id'],
                        'places': salle['capacite']
                    })
                    
                    self.add_used_slot(
                        date_heure,
                        evt['duree_minutes'],
                        salle['id']
                    )
                    id_seance += 1

        # Génération des clients et réservations
        id_client = 100
        id_reservation = 100
        id_billet = 100

        for _ in range(nb_reservations):
            # Sélection ou création du client
            if random.random() < 0.3 and self.clients:  # 30% de réutilisation
                client = random.choice(self.clients)
            else:
                client = {
                    'id': id_client,
                    'nom': random.choice(Config.NOMS),
                    'prenom': random.choice(Config.PRENOMS)
                }
                self.clients.append(client)
                id_client += 1

            # Sélection de la séance et création de la réservation
            if self.seances:
                seance = random.choice(self.seances)
                evt = next(e for e in self.events if e['id'] == seance['event_id'])
                statut = random.choices(
                    list(Config.STATUTS.keys()),
                    weights=list(Config.STATUTS.values())
                )[0]

                resa = {
                    'id': id_reservation,
                    'client_id': client['id'],
                    'date': datetime.now(),
                    'statut': statut,
                    'total': 0
                }

                # Création des billets
                nb_billets = random.randint(1, 4)
                total = 0

                for _ in range(nb_billets):
                    tarif = random.choice(list(Config.TARIFS.keys()))
                    prix = evt['prix'] * Config.TARIFS[tarif]
                    
                    self.billets.append({
                        'id': id_billet,
                        'resa_id': id_reservation,
                        'seance_id': seance['id'],
                        'tarif': tarif,
                        'prix': prix,
                        'code': f"B{id_billet}-{id_reservation}-{uuid.uuid4().hex[:8]}",
                        'statut': 'VALIDE' if statut == 'PAYE' else statut
                    })
                    total += prix
                    id_billet += 1

                resa['total'] = total
                self.reservations.append(resa)
                id_reservation += 1

    def exporter_sql(self, filename: str):
        with open(filename, 'w', encoding='utf-8') as f:
            f.write('BEGIN;\n\n')

            # Salles
            for s in self.salles:
                f.write(
                    f"INSERT INTO SALLE VALUES ({s['id']}, '{s['nom']}', "
                    f"{s['capacite']}, '{s['config']}');\n"
                )
            f.write('\n')

            # Événements
            for e in self.events:
                f.write(
                    f"INSERT INTO EVENEMENT VALUES ({e['id']}, '{e['titre']}', "
                    f"'Description de {e['titre']}', '{e['categorie']}', "
                    f"'{e['duree']}:00', {e['prix']});\n"
                )
            f.write('\n')

            # Séances avec vérification supplémentaire des créneaux
            for s in self.seances:
                f.write(
                    f"INSERT INTO SEANCE VALUES ({s['id']}, {s['event_id']}, "
                    f"'{s['date']}', {s['salle_id']}, {s['places']});\n"
                )
            f.write('\n')

            # Clients
            for c in self.clients:
                email = f"{c['prenom'].lower()}.{c['nom'].lower()}@email.com"
                tel = f"06{random.randint(10000000, 99999999)}"
                f.write(
                    f"INSERT INTO CLIENT VALUES ({c['id']}, '{c['nom']}', "
                    f"'{c['prenom']}', '{email}', '{tel}');\n"
                )
            f.write('\n')

            # Réservations
            for r in self.reservations:
                f.write(
                    f"INSERT INTO RESERVATION VALUES ({r['id']}, {r['client_id']}, "
                    f"'{r['date']}', '{r['statut']}', {r['total']});\n"
                )
            f.write('\n')

            # Billets
            for b in self.billets:
                f.write(
                    f"INSERT INTO BILLET VALUES ({b['id']}, {b['resa_id']}, "
                    f"{b['seance_id']}, '{b['tarif']}', {b['prix']}, "
                    f"'{b['code']}', '{b['statut']}');\n"
                )

            f.write('\nCOMMIT;\n')

if __name__ == '__main__':
    # Générer d'abord les données de base
    gen = Generator()
    gen.generer_donnees(nb_events=10, nb_jours=60, nb_reservations=1000)
    gen.exporter_sql('donnees_billetterie.sql')
    
    print("Génération des données terminée!")