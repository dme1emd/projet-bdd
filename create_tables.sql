-- Création des tables pour la base de données
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE EVENEMENT (
    id_evenement SERIAL PRIMARY KEY,
    titre VARCHAR(255),
    description TEXT,
    categorie VARCHAR(255),
    duree VARCHAR(50),
    prix_standard DECIMAL(10, 2)
);

CREATE TABLE SALLE (
    id_salle SERIAL PRIMARY KEY,
    nom VARCHAR(255),
    capacite INT,
    configuration VARCHAR(255)
);

CREATE TABLE SEANCE (
    id_seance SERIAL PRIMARY KEY,
    id_evenement INT,
    date_heure TIMESTAMP,
    salle_id INT,
    places_disponibles INT,
    FOREIGN KEY (id_evenement) REFERENCES EVENEMENT(id_evenement),
    FOREIGN KEY (salle_id) REFERENCES SALLE(id_salle)
);

CREATE TABLE CLIENT (
    id_client SERIAL PRIMARY KEY,
    nom VARCHAR(255),
    prenom VARCHAR(255),
    email VARCHAR(255),
    telephone VARCHAR(20)
);

CREATE TABLE RESERVATION (
    id_reservation SERIAL PRIMARY KEY,
    id_client INT,
    date_reservation TIMESTAMP,
    statut_paiement VARCHAR(50),
    montant_total DECIMAL(10, 2),
    FOREIGN KEY (id_client) REFERENCES CLIENT(id_client)
);

CREATE TABLE BILLET (
    id_billet SERIAL PRIMARY KEY,
    id_reservation INT,
    id_seance INT,
    type_tarif VARCHAR(50),
    prix_final DECIMAL(10, 2),
    code_barre VARCHAR(50),
    statut VARCHAR(50),
    FOREIGN KEY (id_reservation) REFERENCES RESERVATION(id_reservation),
    FOREIGN KEY (id_seance) REFERENCES SEANCE(id_seance)
);