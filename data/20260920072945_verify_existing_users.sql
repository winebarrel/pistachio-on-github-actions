-- Treat everyone who already had an account as verified.
-- New users start unverified, per the column default.

UPDATE users SET verified = true;
