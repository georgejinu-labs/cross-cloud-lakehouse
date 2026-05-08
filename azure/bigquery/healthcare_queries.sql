-- BigQuery Omni federated queries — data lives in Azure ADLS Gen2

-- Query 1: Claims summary per member
SELECT
  m.first_name,
  m.last_name,
  COUNT(c.claim_id) AS total_claims,
  SUM(c.amount)     AS total_billed
FROM `cross-cloud-lh-azure.healthcare_lakehouse.members` m
JOIN `cross-cloud-lh-azure.healthcare_lakehouse.claims`  c ON m.member_id = c.member_id
GROUP BY m.first_name, m.last_name
ORDER BY total_billed DESC;

-- Query 2: Denied claims
SELECT
  m.first_name,
  m.last_name,
  c.claim_id,
  c.diagnosis_code,
  c.amount,
  c.status
FROM `cross-cloud-lh-azure.healthcare_lakehouse.members` m
JOIN `cross-cloud-lh-azure.healthcare_lakehouse.claims`  c ON m.member_id = c.member_id
WHERE c.status = 'DENIED';

-- Query 3: Total billed by plan
SELECT
  m.plan_id,
  COUNT(DISTINCT m.member_id) AS members,
  COUNT(c.claim_id)           AS total_claims,
  SUM(c.amount)               AS total_billed
FROM `cross-cloud-lh-azure.healthcare_lakehouse.members` m
JOIN `cross-cloud-lh-azure.healthcare_lakehouse.claims`  c ON m.member_id = c.member_id
GROUP BY m.plan_id
ORDER BY total_billed DESC;
