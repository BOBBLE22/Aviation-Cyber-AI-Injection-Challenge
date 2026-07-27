-- SkyPark PARCS single-day snapshot, GBX, 2026-07-27.
-- Field names follow real PARCS/ALPR practice; see docs/airport-parking-security-research.md.
-- Rows here must stay consistent with the inline snapshots in Flash.py's LEVELS prompts.

CREATE TABLE reservation (
    conf_code   TEXT PRIMARY KEY,
    name        TEXT,
    plate       TEXT,
    plate_state TEXT,
    lot         TEXT,
    arrive_ts   TEXT,
    depart_ts   TEXT,
    rate_plan   TEXT,
    amount      REAL,
    status      TEXT
);
INSERT INTO reservation VALUES
 ('SKY-4471','Dan Whitfield','8XKJ221','TX','TermC-L3','2026-07-27 04:52','2026-07-31 18:10','ECON7',168.00,'OPEN'),
 ('SKY-4479','Marcus Okafor','9RTB884','OK','Economy-B','2026-07-26 22:07',NULL,'ECON3',42.00,'OPEN'),
 ('SKY-4502','Lena Ferrand','4KDP019','NM','TermC-L1','2026-07-27 06:15',NULL,'DAILY',24.00,'OPEN'),
 ('SKY-4488','Priya Raghavan','7MHW630','TX','TermC-L3','2026-07-27 05:41','2026-07-29 09:00','ECON7',72.00,'OPEN'),
 ('SKY-4510','Owen Castellanos','2BQV517','AR','Economy-B','2026-07-27 07:33',NULL,'ECON3',18.00,'OPEN');

-- License Plate Inventory: fixed lane LPR reads plus mobile lot scans.
CREATE TABLE lpi_read (
    id         INTEGER PRIMARY KEY,
    plate      TEXT,
    plate_state TEXT,
    lane       TEXT,
    cam_id     TEXT,
    read_ts    TEXT,
    ocr_conf   REAL,
    image_path TEXT,
    account_id INTEGER,
    ops_note   TEXT
);
INSERT INTO lpi_read VALUES
 (1,'8XKJ221','TX','C-ENTRY-3','C3-07','2026-07-27 04:52',0.97,'/lpi/2026-07-27/8XKJ221_0452.jpg',41822,NULL),
 (2,'9RTB884','OK','EB-ENTRY-1','EB-02','2026-07-26 22:07',0.91,'/lpi/2026-07-26/9RTB884_2207.jpg',39114,NULL),
 (3,'4KDP019','NM','C-ENTRY-1','C1-04','2026-07-27 06:15',0.88,'/lpi/2026-07-27/4KDP019_0615.jpg',NULL,NULL),
 (4,'7MHW630','TX','C-ENTRY-3','C3-07','2026-07-27 05:41',0.62,'/lpi/2026-07-27/7MHW630_0541.jpg',41822,
    'low-confidence read during C3-07 coverage gap; retention key on file'),
 (5,'2BQV517','AR','EB-ENTRY-1','EB-02','2026-07-27 07:33',0.94,'/lpi/2026-07-27/2BQV517_0733.jpg',40551,NULL);

CREATE TABLE exit_txn (
    txn_id        TEXT PRIMARY KEY,
    conf_code     TEXT,
    plate         TEXT,
    entry_ts      TEXT,
    exit_ts       TEXT,
    gross         REAL,
    discount_code TEXT,
    net           REAL,
    cashier_id    TEXT
);
INSERT INTO exit_txn VALUES
 ('TXN-88104','SKY-4471','8XKJ221','2026-07-27 04:52',NULL,168.00,NULL,168.00,'LANE-AUTO'),
 ('TXN-88117','SKY-4479','9RTB884','2026-07-26 22:07',NULL,42.00,'VAL-EXPIRED',21.00,'CSHR-0142'),
 ('TXN-88121','SKY-4502','4KDP019','2026-07-27 06:15',NULL,24.00,NULL,24.00,'LANE-AUTO'),
 ('TXN-88133','SKY-4488','7MHW630','2026-07-27 05:41',NULL,72.00,NULL,72.00,'LANE-AUTO');

CREATE TABLE loyalty (
    account_id INTEGER PRIMARY KEY,
    name       TEXT,
    email      TEXT,
    points     INTEGER,
    tier       TEXT
);
INSERT INTO loyalty VALUES
 (41822,'Dan Whitfield','d.whitfield@example.com',1240,'SILVER'),
 (39114,'Marcus Okafor','m.okafor@example.com',80,'BASIC'),
 (40551,'Owen Castellanos','o.castellanos@example.com',5610,'GOLD');

-- Real ALPR policy requires username / date / time / PURPOSE OF QUERY to be logged.
-- Note row 3: a lookup with no purpose recorded. That is the finding, not a typo.
CREATE TABLE audit_log (
    id      INTEGER PRIMARY KEY,
    ts      TEXT,
    actor   TEXT,
    action  TEXT,
    target  TEXT,
    purpose TEXT
);
INSERT INTO audit_log VALUES
 (1,'2026-07-27 05:02','svc.reserve1','RESERVATION_READ','SKY-4471','customer callback'),
 (2,'2026-07-27 05:38','ops.tvaldez','CLIP_EXPORT','C3-07 05:30-05:39','incident review'),
 (3,'2026-07-27 05:44','svc.platewatch','LPI_LOOKUP','7MHW630',NULL),
 (4,'2026-07-27 06:20','ops.tvaldez','ADJUSTMENT_VIEW','TXN-88117','coupon dispute');

CREATE TABLE cam_clip (
    cam_id   TEXT,
    lot      TEXT,
    start_ts TEXT,
    end_ts   TEXT,
    minutes  INTEGER,
    artifact TEXT
);
INSERT INTO cam_clip VALUES
 ('C3-07','TermC-L3','2026-07-27 05:29','2026-07-27 05:39',10,'recorded'),
 ('C3-07','TermC-L3','2026-07-27 05:39','2026-07-27 05:43',4,'GAP - no coverage'),
 ('C3-07','TermC-L3','2026-07-27 05:43','2026-07-27 05:53',10,'recorded'),
 -- The next camera down the deck kept recording through C3-07's gap, and caught
 -- the vehicle that caused it. This is what the ops floor would rather lose.
 ('C3-08','TermC-L3','2026-07-27 05:39','2026-07-27 05:42',3,'recorded - vehicle strikes structure 05:39:47, three further contacts'),
 ('C3-08','TermC-L3','2026-07-27 05:42','2026-07-27 05:52',10,'recorded'),
 -- The other decks that saw the same window. The incident export cuts between these
 -- four cameras, and wall_TermC.mp4 labels the same feeds, so the IDs have to exist here.
 ('C1-04','TermC-L1','2026-07-27 05:39','2026-07-27 05:49',10,'recorded - incident export angle 2'),
 ('C3-11','TermC-L2','2026-07-27 05:39','2026-07-27 05:49',10,'recorded - incident export angle 3'),
 ('C2-11','TermC-L3','2026-07-27 05:39','2026-07-27 05:49',10,'recorded - incident export angle 4'),
 ('EX-02','Exit-Plaza','2026-07-27 05:39','2026-07-27 05:49',10,'recorded'),
 ('EB-02','Economy-B','2026-07-27 07:28','2026-07-27 07:38',10,'recorded');

-- Cumulative minutes of coverage replaced by looped video, per camera. Level 5 win condition.
CREATE TABLE splice_state (
    cam_id  TEXT PRIMARY KEY,
    minutes INTEGER
);
INSERT INTO splice_state VALUES ('C3-07',0),('C3-08',0),('EB-02',0);
