--
-- Test cachable expressions
--
-- If the NOTICE outputs of these functions change, you've probably broken
-- something with the CacheExpr optimization
--

create function stable_true() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE TRUE'; return true; end;$$;
create function volatile_true() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE TRUE'; return true; end;$$;
create function stable_false() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE FALSE'; return false; end;$$;
create function volatile_false() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE FALSE'; return false; end;$$;

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

prepare param_test(bool) as select $1 or stable_false() or volatile_true() as b from two;
execute param_test(true);
execute param_test(false);

-- Function calls
create function stable(bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%)', $1; return $1; end;$$;
create function volatile(bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE(%)', $1; return $1; end;$$;

select volatile(volatile_true()) from two;
select stable(stable_true()) from two;
select stable(volatile_true()) from two;
select volatile(stable_true()) from two;

create function stable(bool, bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%, %)', $1, $2; return $1; end;$$;
create function volatile(bool, bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE(%, %)', $1, $2; return $1; end;$$;

select stable(volatile_true(), volatile_false()) from two;
select stable(stable_true(), volatile_false()) from two;
select stable(stable_true(), stable_false()) from two;
select volatile(volatile_true(), volatile_false()) from two;
select volatile(stable_true(), volatile_false()) from two;
select volatile(stable_true(), stable_false()) from two;

-- Default arguments
create function stable_def(a bool = stable_false(), b bool = volatile_true())
returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE(%, %)', $1, $2; return $1; end;$$;

select stable_def() from two;
select stable_def(b := stable_true()) from two;
select stable_def(volatile_false()) from two;

-- Operators
create function stable_eq(bool, bool) returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE % == %', $1, $2; return $1 = $2; end;$$;
create function volatile_eq(bool, bool) returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE % =%%= %', $1, $2; return $1 = $2; end;$$;

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
$$begin raise notice 'STABLE NULL'; return null; end;$$;
create function volatile_null() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE NULL'; return null; end;$$;

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

-- The end
drop table two;
