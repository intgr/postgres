setup
{
  CREATE TABLE foo (i int);
  INSERT INTO foo VALUES (1);
}

teardown
{
  DROP TABLE foo;
}

session "s1"
step "begin"
{
  BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  -- Force snapshot open
  SELECT 1 AS foo FROM txid_current();
}
step "select"	{ SELECT * FROM foo; }
step "roll"		{ ROLLBACK; }

session "s2"
step "trunc"	{ TRUNCATE TABLE foo; }
