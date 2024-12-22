-- Initialisation des donnEes de base
BEGIN;

-- CrEation des salles
INSERT INTO SALLE (id_salle, nom, capacite, configuration) VALUES
(1, 'Grande Salle OpEra', 500, 'Theatre'),
(2, 'Salle Mozart', 200, 'Concert'),
(3, 'Auditorium Principal', 300, 'Conference');

-- CrEation des sEances
INSERT INTO SEANCE (id_seance, id_evenement, date_heure, salle_id, places_disponibles) VALUES
(1, 1, '2025-01-15 20:00:00', 1, 500),
(2, 1, '2025-01-16 20:00:00', 1, 500),
(3, 2, '2025-01-20 19:30:00', 2, 200),
(4, 3, '2025-01-22 21:00:00', 3, 300);

COMMIT;

-- ===============================
-- TRANSACTION 1: REservation familiale
-- ===============================
BEGIN;

-- CrEation du client
INSERT INTO CLIENT (id_client, nom, prenom, email, telephone)
VALUES (1, 'Dubois', 'Marie', 'marie.dubois@email.com', '0612345678');

-- REservation pour une famille de 4 personnes
INSERT INTO RESERVATION (id_reservation, id_client, date_reservation, statut_paiement, montant_total)
VALUES (1, 1, CURRENT_TIMESTAMP, 'PAYE', 180.00);

-- CrEation des billets (2 adultes, 2 enfants)
INSERT INTO BILLET (id_billet, id_reservation, id_seance, type_tarif, prix_final, code_barre, statut) VALUES
(1, 1, 1, 'STANDARD', 45.00, 'BIL-1-FAM-' || gen_random_uuid(), 'VALIDE'),
(2, 1, 1, 'STANDARD', 45.00, 'BIL-2-FAM-' || gen_random_uuid(), 'VALIDE'),
(3, 1, 1, 'REDUIT', 45.00 * 0.5, 'BIL-3-FAM-' || gen_random_uuid(), 'VALIDE'),
(4, 1, 1, 'REDUIT', 45.00 * 0.5, 'BIL-4-FAM-' || gen_random_uuid(), 'VALIDE');

UPDATE SEANCE SET places_disponibles = places_disponibles - 4 WHERE id_seance = 1;

COMMIT;

-- ===============================
-- TRANSACTION 2: REservation groupe
-- ===============================
BEGIN;

INSERT INTO CLIENT (id_client, nom, prenom, email, telephone)
VALUES (2, 'Martin', 'Jean', 'jean.martin@email.com', '0623456789');

-- REservation groupe avec remise 20%
INSERT INTO RESERVATION (id_reservation, id_client, date_reservation, statut_paiement, montant_total)
VALUES (2, 2, CURRENT_TIMESTAMP, 'PAYE', 35.00 * 10 * 0.8);

-- CrEation de 10 billets groupe
DO $$ 
DECLARE 
    i INT := 1;
BEGIN
    WHILE i <= 10 LOOP
        INSERT INTO BILLET (id_billet, id_reservation, id_seance, type_tarif, prix_final, code_barre, statut)
        VALUES 
        (4 + i, 2, 3, 'GROUPE', 35.00 * 0.8, 'BIL-GRP-' || gen_random_uuid(), 'VALIDE');
        i := i + 1;
    END LOOP;
END $$;

UPDATE SEANCE SET places_disponibles = places_disponibles - 10 WHERE id_seance = 3;

COMMIT;

-- ===============================
-- TRANSACTION 3: REservation avec annulation
-- ===============================
BEGIN;

INSERT INTO CLIENT (id_client, nom, prenom, email, telephone)
VALUES (3, 'Durand', 'Pierre', 'pierre.durand@email.com', '0634567890');

-- REservation initiale
INSERT INTO RESERVATION (id_reservation, id_client, date_reservation, statut_paiement, montant_total)
VALUES (3, 3, CURRENT_TIMESTAMP, 'PAYE', 25.00 * 2);

-- CrEation de 2 billets
INSERT INTO BILLET (id_billet, id_reservation, id_seance, type_tarif, prix_final, code_barre, statut) VALUES
(15, 3, 4, 'STANDARD', 25.00, 'BIL-15-' || gen_random_uuid(), 'ANNULE'),
(16, 3, 4, 'STANDARD', 25.00, 'BIL-16-' || gen_random_uuid(), 'ANNULE');

-- Simulation d'annulation
UPDATE RESERVATION SET statut_paiement = 'REMBOURSE' WHERE id_reservation = 3;
UPDATE BILLET SET statut = 'ANNULE' WHERE id_reservation = 3;
UPDATE SEANCE SET places_disponibles = places_disponibles + 2 WHERE id_seance = 4;

COMMIT;

-- ===============================
-- TRANSACTION 4: REservation dernière minute
-- ===============================
BEGIN;

INSERT INTO CLIENT (id_client, nom, prenom, email, telephone)
VALUES (4, 'Petit', 'Sophie', 'sophie.petit@email.com', '0645678901');

-- REservation last minute avec rEduction
INSERT INTO RESERVATION (id_reservation, id_client, date_reservation, statut_paiement, montant_total)
VALUES (4, 4, CURRENT_TIMESTAMP, 'PAYE', 45.00 * 0.7);

INSERT INTO BILLET (id_billet, id_reservation, id_seance, type_tarif, prix_final, code_barre, statut)
VALUES (17, 4, 2, 'LAST_MINUTE', 45.00 * 0.7, 'BIL-17-LM-' || gen_random_uuid(), 'VALIDE');

UPDATE SEANCE SET places_disponibles = places_disponibles - 1 WHERE id_seance = 2;

COMMIT;

-- ===============================
-- TRANSACTION 5: REservation VIP
-- ===============================
BEGIN;

INSERT INTO CLIENT (id_client, nom, prenom, email, telephone)
VALUES (5, 'Lambert', 'François', 'francois.lambert@email.com', '0656789012');

-- REservation VIP avec supplEment
INSERT INTO RESERVATION (id_reservation, id_client, date_reservation, statut_paiement, montant_total)
VALUES (5, 5, CURRENT_TIMESTAMP, 'PAYE', 45.00 * 2 * 1.5);

-- CrEation de 2 billets VIP
INSERT INTO BILLET (id_billet, id_reservation, id_seance, type_tarif, prix_final, code_barre, statut) VALUES
(18, 5, 1, 'VIP', 45.00 * 1.5, 'BIL-18-VIP-' || gen_random_uuid(), 'VALIDE'),
(19, 5, 1, 'VIP', 45.00 * 1.5, 'BIL-19-VIP-' || gen_random_uuid(), 'VALIDE');

UPDATE SEANCE SET places_disponibles = places_disponibles - 2 WHERE id_seance = 1;

COMMIT;