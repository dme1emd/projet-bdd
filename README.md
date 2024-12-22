# Projet de Billetterie

Ce projet est un système de gestion de billetterie pour des événements avec des fonctionnalités avancées telles que la gestion des séances, des réservations et des billetteries, ainsi que le calcul de divers rapports.
### 1. Configurer la base de données

Commence par créer les tables de la base de données en exécutant les scripts SQL dans l'ordre suivant :

1. **`\i create-tables.sql`**
2. **`\i fonctions.sql`**
3. **`\i triggers.sql`**
4. **`python3 data-generator.py`**
5. **`\i donnees-billeterie.sql`**
6. **`\i transaction.sql`** 
   Ce script crée toutes les tables nécessaires à la gestion de la billetterie (clients, réservations, billets, séances, événements, salles, etc.).

## Fonctionnalités

1. **Calcul du taux de remplissage d'une séance**  
   La fonction `fn_TauxRemplissage(id_seance INT)` permet de calculer le taux de remplissage d'une séance en fonction du nombre de places occupées par rapport à la capacité totale de la salle.

2. **Rapport des ventes par période**  
   La fonction `fn_RapportVentes(date_debut TIMESTAMP, date_fin TIMESTAMP)` génère un rapport des ventes par période, incluant des informations sur l'événement, les ventes, le montant total et le taux de remplissage.

3. **Calcul du prix avec réduction**  
   La fonction `fn_CalculPrixReduit(prix_base DECIMAL(10, 2), type_tarif VARCHAR(50))` applique une réduction sur le prix des billets en fonction du type de tarif (standard, réduit, étudiant, senior, groupe).

4. **Vérification de la disponibilité des créneaux**  
   La fonction `fn_DisponibilitesPeriode(id_evenement INT, date_debut TIMESTAMP, date_fin TIMESTAMP, nb_places_min INT)` permet de vérifier la disponibilité des places pour un événement donné sur une période spécifique.

5. **Analyse des statistiques des clients**  
   La fonction `fn_StatistiquesClient(id_client INT)` génère des statistiques détaillées sur un client, y compris le nombre de réservations, le montant total des achats, les catégories fréquentes et les types de billets achetés.

6. **Gestion des créneaux de séance et des conflits**  
   La fonction `fn_validation_date_seance()` vérifie la validité des dates et heures des séances, assure qu'il n'y a pas de conflits d'horaires avec d'autres séances et met à jour le nombre de places disponibles en cas de réservation.

## Tables principales

1. **CLIENT**  
   Contient les informations sur les clients.

2. **RESERVATION**  
   Contient les informations sur les réservations effectuées par les clients.

3. **BILLET**  
   Contient les informations sur les billets réservés, y compris le type et le statut.

4. **SEANCE**  
   Contient les informations sur les séances des événements (heure, salle, etc.).

5. **SALLE**  
   Contient les informations sur les salles où les séances ont lieu.

6. **EVENEMENT**  
   Contient les informations sur les événements (titre, durée, etc.).

## Transactions d'exemple

Voici des exemples de transactions utilisées dans le système pour simuler des réservations, des annulations et des réservations de dernière minute :

1. **Réservation familiale**  
   Une réservation pour une famille de 4 personnes avec deux adultes et deux enfants, avec des billets standard et réduits.

2. **Réservation de groupe**  
   Une réservation pour un groupe de 10 personnes avec une réduction de 20%.

3. **Réservation avec annulation**  
   Une réservation pour deux billets, suivie d'une annulation.

4. **Réservation de dernière minute**  
   Une réservation de dernière minute avec une réduction de 30% sur le prix standard.

5. **Réservation VIP**  
   Une réservation VIP pour 2 personnes avec un supplément de 50%.

## Scripts SQL

Les scripts SQL nécessaires pour créer la base de données et insérer des données initiales, ainsi que pour gérer les transactions et la logique métier, sont fournis.

## Prérequis

- PostgreSQL version 13 ou supérieure.
- Extension `pgcrypto` pour la génération d'UUIDs.

## Installation

1. Clonez ce repository sur votre machine locale.
2. Ouvrez une session PostgreSQL.
3. Exécutez les scripts SQL pour créer les tables et les fonctions dans votre base de données.
4. Utilisez les fonctions fournies pour gérer les réservations et les événements.

## License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

