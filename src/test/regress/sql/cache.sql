--
-- Test cachable expressions
--
-- If the NOTICE outputs of these functions change, you've probably broken
-- something with the CacheExpr optimization
--

create function stable_true() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE TRUE'; return true; end$$;
create function volatile_true() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE TRUE'; return true; end$$;
create function stable_false() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE FALSE'; return false; end$$;
create function volatile_false() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE FALSE'; return false; end$$;

-- Table with two rows
create table two (i int);
insert into two values (1), (2);

-- Boolean expressions
select stable_false() or volatile_true() or stable_true() as b from two;
select stable_true() or volatile_false() or stable_false() as b from two;
select stable_false() or volatile_true() as b from two;
select stable_false() or stable_false() or volatile_true() as b from two;
select volatile_true() or volatile_false() or stable_false() as b from two;
select volatile_false() or volatile_true() or stable_false() as b from two;

select stable_true() and volatile_false() and stable_false() as b from two;
select stable_false() and volatile_true() and stable_true() as b from two;
select stable_true() and volatile_false() as b from two;
select stable_true() and stable_true() and volatile_false() as b from two;
select volatile_true() and volatile_false() and stable_true() as b from two;
select volatile_false() and volatile_true() and stable_true() as b from two;

select not stable_true() as b from two;
select not volatile_true() as b from two;

-- Bind params
prepare param_test(bool) as select $1 or stable_false() or volatile_true() as b from two;
execute param_test(true);
execute param_test(false);

-- Function calls
create function stable(bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%)', $1; return $1; end$$;
create function volatile(bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE(%)', $1; return $1; end$$;

select volatile(volatile_true()) from two;
select stable(stable_true()) from two;
select stable(volatile_true()) from two;
select volatile(stable_true()) from two;

create function stable(bool, bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%, %)', $1, $2; return $1; end$$;
create function volatile(bool, bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE(%, %)', $1, $2; return $1; end$$;

select stable(volatile_true(), volatile_false()) from two;
select stable(stable_true(), volatile_false()) from two;
select stable(stable_true(), stable_false()) from two;
select volatile(volatile_true(), volatile_false()) from two;
select volatile(stable_true(), volatile_false()) from two;
select volatile(stable_true(), stable_false()) from two;

-- Default arguments
create function stable_def(a bool = stable_false(), b bool = volatile_true())
returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%, %)', $1, $2; return $1; end$$;

select stable_def() from two;
select stable_def(b := stable_true()) from two;
select stable_def(volatile_false()) from two;

-- Operators
create function stable_eq(bool, bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE % == %', $1, $2; return $1 = $2; end$$;
create function volatile_eq(bool, bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE % =%%= %', $1, $2; return $1 = $2; end$$;

create operator == (procedure = stable_eq, leftarg=bool, rightarg=bool);
create operator =%= (procedure = volatile_eq, leftarg=bool, rightarg=bool);

select volatile_true() == volatile_false() from two;
select stable_true() == volatile_false() from two;
select stable_true() == stable_false() from two;
select volatile_true() =%= volatile_false() from two;
select stable_true() =%= volatile_false() from two;
select stable_true() =%= stable_false() from two;

select (volatile_true() or stable_true()) == true as b from two;

-- Coalesce
create function stable_null() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE NULL'; return null; end$$;
create function volatile_null() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE NULL'; return null; end$$;

select coalesce(stable_null(), stable_true()) from two;
select coalesce(stable_true(), volatile_null()) from two;
select coalesce(volatile_null(), stable_null(), volatile_true()) from two;

-- Case/when
select case when stable_true() then 't' else volatile_false() end as b from two;
select case when volatile_true() then stable_true() else stable_false() end as b from two;
select case when i=1 then stable_true() else stable_false() end as b from two;
select case when i=1 then volatile_true() else volatile_false() end as b from two;

select case when 't' then 't' else volatile_false() end == true as b from two;

-- Coerce via I/O
select stable_true()::text::bool == true as b from two;
select volatile_true()::text::bool == true as b from two;

-- IS DISTINCT FROM
select (stable_true() is not distinct from volatile_false()) as b from two;
select (stable_true() is distinct from stable_false()) == false as b from two;
select (volatile_true() is distinct from null) as b from two;

-- IS NULL
select volatile_true() is null == false as b from two;
select stable_null() is not null == true as b from two;

-- Boolean tests
select volatile_false() is true == true as b from two;
select stable_null() is not unknown == false as b from two;

-- Field select -- not currently cached
create function stable_row(a out int, b out int) STABLE language plpgsql as
$$begin raise notice 'STABLE ROW'; a = 1; b = 2; end$$;

select (stable_row()).a from two;

-- WHERE clause
begin;
-- stable_true is evaluated twice due to planning estimates
declare stable_where cursor for select * from two where i > stable_true()::int;
fetch all from stable_where;
declare volatile_where cursor for select * from two where i = volatile_false()::int;
fetch all from volatile_where;
rollback;

-- INSERT column default expressions
create table defaults (
	dummy int,
	a bool default stable_true(),
	b bool default volatile_true()
);
insert into defaults (dummy) values(0), (1);

-- ALTER COLUMN TYPE USING
alter table defaults alter column a type bool using stable_false();
alter table defaults alter column a type bool using volatile_false();

-- COPY FROM with default expressions
copy defaults (dummy) from stdin;
2
3
\.

-- PL/pgSQL Simple expressions
-- Make sure we don't cache simple expressions -- these expressions are only
-- initialized once per transaction and then executed multiple times
create function stable_max() returns int STABLE language plpgsql as
$$begin return (select max(i) from two); end$$;

create function simple() returns int STABLE language plpgsql as
$$begin return stable_max(); end$$;

begin;
select simple();
insert into two values(3);
select simple();
rollback;

-- The end
drop table defaults;
drop table two;
