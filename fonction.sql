-- ================================================
-- 1. FONCTION : Calculer le taux de remplissage d'une séance
-- ================================================

CREATE OR REPLACE FUNCTION fn_TauxRemplissage(id_seance INT) RETURNS DECIMAL(5, 2) AS $$
DECLARE
    capacite_totale INT;
    places_occupees INT;
    taux DECIMAL(5, 2);
BEGIN
    -- Récupère la capacité totale de la salle
    SELECT S.capacite
    INTO capacite_totale
    FROM seance SE
    JOIN salle S ON SE.salle_id = S.id_salle
    WHERE SE.id_seance = $1;

    -- Gérer le cas où aucune séance n'a été trouvée
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Séance avec ID % inexistante', $1;
    END IF;

    -- Calcule le nombre de places occupées (billets valides uniquement)
    SELECT COUNT(*)
    INTO places_occupees
    FROM billet B
    WHERE B.id_seance = $1 AND B.statut = 'VALIDE';

    -- Calcule le taux de remplissage
    IF capacite_totale > 0 THEN
        taux := (places_occupees * 100.0) / capacite_totale;
    ELSE
        taux := 0;
    END IF;

    RETURN ROUND(taux, 2);
END;
$$ LANGUAGE PLPGSQL;

-- ================================================
-- 2. FONCTION : Générer un rapport de ventes par période
-- ================================================

CREATE OR REPLACE FUNCTION fn_RapportVentes(
    date_debut TIMESTAMP, 
    date_fin TIMESTAMP
) RETURNS TABLE (
    evenement VARCHAR(255),
    date_heure TIMESTAMP, 
    nombre_billets INTEGER, 
    montant_total DECIMAL(10, 2),
    taux_remplissage DECIMAL(5, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        E.titre,
        S.date_heure,
        COUNT(B.id_billet)::INTEGER,
        SUM(B.prix_final)::DECIMAL(10, 2),
        fn_TauxRemplissage(S.id_seance)
    FROM EVENEMENT E
    JOIN SEANCE S ON E.id_evenement = S.id_evenement
    JOIN BILLET B ON S.id_seance = B.id_seance
    JOIN RESERVATION R ON B.id_reservation = R.id_reservation
    WHERE S.date_heure BETWEEN date_debut AND date_fin
      AND R.statut_paiement = 'PAYE'
    GROUP BY E.titre, S.date_heure, S.id_seance
    ORDER BY S.date_heure;
END;
$$ LANGUAGE PLPGSQL;

-- ================================================
-- 3. FONCTION : Calculer le prix avec réduction
-- ================================================

CREATE OR REPLACE FUNCTION fn_CalculPrixReduit(
    prix_base DECIMAL(10, 2), 
    type_tarif VARCHAR(50)
) RETURNS DECIMAL(10, 2) AS $$
BEGIN
    RETURN CASE type_tarif
        WHEN 'STANDARD' THEN prix_base
        WHEN 'REDUIT' THEN prix_base * 0.8 -- 20% de réduction
        WHEN 'ETUDIANT' THEN prix_base * 0.5 -- 50% de réduction
        WHEN 'SENIOR' THEN prix_base * 0.7 -- 30% de réduction
        WHEN 'GROUPE' THEN prix_base * 0.85 -- 15% de réduction
        ELSE prix_base
    END;
END;
$$ LANGUAGE PLPGSQL;

-- ================================================
-- 4. FONCTION : Vérifier la disponibilité sur une période
-- ================================================

CREATE OR REPLACE FUNCTION fn_DisponibilitesPeriode(
    id_evenement_param INT, 
    date_debut TIMESTAMP, 
    date_fin TIMESTAMP, 
    nb_places_min INT = 1
) RETURNS TABLE (
    id_seance INT, 
    date_heure TIMESTAMP, 
    salle VARCHAR(255), 
    places_disponibles INT, 
    prix_standard DECIMAL(10, 2), 
    taux_remplissage DECIMAL(5, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        S.id_seance,
        S.date_heure,
        SA.nom,
        S.places_disponibles,
        E.prix_standard,
        fn_TauxRemplissage(S.id_seance)
    FROM SEANCE S
    JOIN SALLE SA ON S.salle_id = SA.id_salle
    JOIN EVENEMENT E ON S.id_evenement = E.id_evenement
    WHERE E.id_evenement = id_evenement_param
      AND S.date_heure BETWEEN date_debut AND date_fin
      AND S.places_disponibles >= nb_places_min
    ORDER BY S.date_heure;
END;
$$ LANGUAGE PLPGSQL;

-- ================================================
-- 5. FONCTION : Analyser les statistiques client
-- ================================================

CREATE OR REPLACE FUNCTION fn_StatistiquesClient(
    id_client_param INT
) RETURNS TABLE (
    nom_client VARCHAR(255), 
    prenom_client VARCHAR(255), 
    email VARCHAR(255), 
    nombre_reservations INT, 
    montant_total_achats DECIMAL(10, 2), 
    derniere_reservation TIMESTAMP, 
    categories_frequentes VARCHAR(255), 
    panier_moyen DECIMAL(10, 2), 
    billets_par_type JSON
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT
            C.nom,
            C.prenom,
            C.email,
            COUNT(DISTINCT R.id_reservation) AS nb_reservations,
            SUM(B.prix_final) AS total_achats,
            MAX(R.date_reservation) AS derniere_resa,
            STRING_AGG(DISTINCT E.categorie, ', ') AS categories,
            AVG(B.prix_final) AS avg_panier,
            JSON_OBJECT_AGG(B.type_tarif, COUNT(B.id_billet)) AS billets_types
        FROM CLIENT C
        LEFT JOIN RESERVATION R ON C.id_client = R.id_client
        LEFT JOIN BILLET B ON R.id_reservation = B.id_reservation
        LEFT JOIN SEANCE S ON B.id_seance = S.id_seance
        LEFT JOIN EVENEMENT E ON S.id_evenement = E.id_evenement
        WHERE C.id_client = id_client_param
        GROUP BY C.id_client, C.nom, C.prenom, C.email
    )
    SELECT
        nom,
        prenom,
        email,
        nb_reservations,
        total_achats::DECIMAL(10, 2),
        derniere_resa,
        categories,
        avg_panier::DECIMAL(10, 2),
        billets_types
    FROM stats;
END;
$$ LANGUAGE PLPGSQL;

----------------------------------------------------------------------

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