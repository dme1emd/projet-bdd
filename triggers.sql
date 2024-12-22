-- ================================================
-- 1. TRIGGER : Vérification de la disponibilité des places
-- Vérifie avant l'insertion d'un billet si des places sont disponibles
-- ================================================

CREATE OR REPLACE FUNCTION fn_verif_disponibilite()
RETURNS TRIGGER AS $$
DECLARE
    places_restantes INTEGER;
BEGIN
    -- Récupérer le nombre de places disponibles
    SELECT places_disponibles INTO places_restantes
    FROM seance s
    WHERE s.id_seance = NEW.id_seance;

    -- Vérifier s'il y a assez de places
    IF places_restantes <= 0 THEN
        RAISE EXCEPTION 'Plus de places disponibles pour cette séance';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Création du trigger qui appelle la fonction après l'insertion d'un billet
CREATE TRIGGER TR_VerifDisponibilite
AFTER INSERT ON billet
FOR EACH ROW
EXECUTE FUNCTION fn_verif_disponibilite();

-- ================================================
-- 2. TRIGGER : Historisation des modifications de réservation
-- Garde une trace de toutes les modifications de statut des réservations
-- ================================================

-- Création de la table d'historique
CREATE TABLE historique_reservation (
    id_historique SERIAL PRIMARY KEY,
    id_reservation INT,
    ancien_statut VARCHAR(50),
    nouveau_statut VARCHAR(50),
    date_modification TIMESTAMP,
    utilisateur VARCHAR(100)
);

-- Création de la fonction associée au trigger
CREATE OR REPLACE FUNCTION fn_historique_reservation()
RETURNS TRIGGER AS $$
BEGIN
    -- Insérer une ligne dans la table d'historique si le statut de la réservation a changé
    IF NEW.statut_paiement <> OLD.statut_paiement THEN
        INSERT INTO historique_reservation (
            id_reservation,
            ancien_statut,
            nouveau_statut,
            date_modification,
            utilisateur
        )
        VALUES (
            NEW.id_reservation,
            OLD.statut_paiement,
            NEW.statut_paiement,
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
    END IF;

    -- Retourner la nouvelle ligne après l'update
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Création du trigger qui appelle la fonction après la mise à jour d'une réservation
CREATE TRIGGER tr_historique_reservation
AFTER UPDATE ON reservation
FOR EACH ROW
EXECUTE FUNCTION fn_historique_reservation();


-- ================================================
-- 3. TRIGGER : Calcul automatique du montant total
-- Calcule le montant total d'une réservation basé sur les billets
-- ================================================

-- Création de la fonction associée au trigger
CREATE OR REPLACE FUNCTION fn_calcul_montant_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Mettre à jour le montant total de la réservation
    UPDATE reservation 
    SET montant_total = (
        SELECT SUM(prix_final)
        FROM billet
        WHERE id_reservation = NEW.id_reservation
    )
    WHERE id_reservation = NEW.id_reservation;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Création du trigger qui appelle la fonction après l'insertion, suppression ou mise à jour des billets
CREATE TRIGGER tr_calcul_montant_total
AFTER INSERT OR DELETE OR UPDATE ON billet
FOR EACH ROW
EXECUTE FUNCTION fn_calcul_montant_total();

-- ================================================
-- 4. TRIGGER : Validation des dates de séance
-- Empêche la création de séances dans le passé
-- ================================================

-- Création de la fonction associée au trigger
-- Recréation de la fonction avec gestion améliorée des créneaux
CREATE OR REPLACE FUNCTION fn_validation_date_seance()
RETURNS TRIGGER AS $$
DECLARE
    v_duree INTERVAL;
    v_debut_nouvelle_seance TIMESTAMPTZ;
    v_fin_nouvelle_seance TIMESTAMPTZ;
    v_seance_conflit RECORD;
    v_temps_preparation INTERVAL := INTERVAL '30 minutes';
BEGIN
    -- Récupération de la durée de l'événement
    SELECT CAST(duree AS INTERVAL)
    INTO v_duree
    FROM EVENEMENT E
    WHERE E.id_evenement = NEW.id_evenement;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Événement avec ID % non trouvé', NEW.id_evenement;
    END IF;

    -- Vérification si la séance a une date dans le passé
    IF NEW.date_heure <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Impossible de créer une séance dans le passé';
    END IF;

    -- Calcul des temps de début et fin avec temps de préparation
    v_debut_nouvelle_seance := NEW.date_heure - v_temps_preparation;
    v_fin_nouvelle_seance := NEW.date_heure + v_duree + v_temps_preparation;

    -- Vérification des horaires standards (pas de séance après 23h ou avant 8h)
    IF EXTRACT(HOUR FROM NEW.date_heure) < 8 OR 
       EXTRACT(HOUR FROM NEW.date_heure + v_duree) > 23 THEN
        RAISE EXCEPTION 'Les séances doivent avoir lieu entre 8h00 et 23h00 (durée incluse)';
    END IF;

    -- Recherche des séances en conflit de manière plus précise
    FOR v_seance_conflit IN
        SELECT 
            s.id_seance,
            s.date_heure as debut_seance,
            s.date_heure - v_temps_preparation as debut_avec_prep,
            s.date_heure + CAST(e.duree AS INTERVAL) + v_temps_preparation as fin_avec_prep
        FROM seance s
        JOIN evenement e ON s.id_evenement = e.id_evenement
        WHERE s.salle_id = NEW.salle_id
        AND s.id_seance != COALESCE(NEW.id_seance, -1)
        AND s.date_heure::date = NEW.date_heure::date  -- Même jour uniquement
        ORDER BY s.date_heure
    LOOP
        -- Vérification du chevauchement avec temps de préparation
        IF (v_debut_nouvelle_seance <= v_seance_conflit.fin_avec_prep) AND 
           (v_fin_nouvelle_seance >= v_seance_conflit.debut_avec_prep) THEN
            
            RAISE EXCEPTION 'Conflit d''horaire détecté avec la séance ID: %.
                           \nVotre créneau demandé: % - % (avec temps de préparation)
                           \nCréneau occupé: % - % (avec temps de préparation)', 
                v_seance_conflit.id_seance,
                v_debut_nouvelle_seance,
                v_fin_nouvelle_seance,
                v_seance_conflit.debut_avec_prep,
                v_seance_conflit.fin_avec_prep;
        END IF;
    END LOOP;

    -- Mise à jour des places disponibles si non spécifié
    IF NEW.places_disponibles IS NULL THEN
        SELECT capacite 
        INTO NEW.places_disponibles
        FROM salle 
        WHERE id_salle = NEW.salle_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recréation du trigger
DROP TRIGGER IF EXISTS TR_ValidationDateSeance ON seance;
CREATE TRIGGER TR_ValidationDateSeance
BEFORE INSERT OR UPDATE ON seance
FOR EACH ROW
EXECUTE FUNCTION fn_validation_date_seance();


-- ================================================
-- 5. TRIGGER : Génération automatique des codes-barres
-- Génère un code-barre unique pour chaque nouveau billet
-- ================================================

-- Créer une fonction pour générer un code-barre et insérer les nouveaux billets
CREATE OR REPLACE FUNCTION fn_generation_code_barre()
RETURNS TRIGGER AS $$
DECLARE
    v_code_barre VARCHAR(100);
BEGIN
    -- Génération du code-barre sous la forme "BIL-<id_billet>-<id_reservation>-<date>-<uuid>"
    v_code_barre := 'BIL-' || NEW.id_billet || '-' || NEW.id_reservation || '-' ||
                    TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || 
                    LEFT(UUID_GENERATE_V4()::TEXT, 8);
    
    -- Vérification de l'unicité du code-barre
    IF EXISTS (SELECT 1 FROM billet WHERE code_barre = v_code_barre) THEN
        RAISE EXCEPTION 'Erreur de génération de code-barre unique';
    END IF;

    -- Mise à jour du champ code_barre avant l'insertion
    NEW.code_barre := v_code_barre;

    -- Retourner le nouvel enregistrement
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger qui utilise la fonction
CREATE TRIGGER TR_GenerationCodeBarre
BEFORE INSERT ON billet
FOR EACH ROW
EXECUTE FUNCTION fn_generation_code_barre();

