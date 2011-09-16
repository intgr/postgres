--
-- Test cachable expressions
--

create or replace function stable_true() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE TRUE'; return true; end;$$;
create or replace function volatile_true() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE TRUE'; return true; end;$$;
create or replace function stable_false() returns bool STABLE language plpgsql as
$$begin raise notice 'STABLE FALSE'; return false; end;$$;
create or replace function volatile_false() returns bool VOLATILE language plpgsql as
$$begin raise notice 'VOLATILE FALSE'; return false; end;$$;

-- Boolean expressions
select stable_false() or volatile_true() or stable_true() as b from generate_series(1,2);
select stable_true() or volatile_false() or stable_false() as b from generate_series(1,2);
select stable_false() or volatile_true() as b from generate_series(1,2);
select stable_false() or stable_false() or volatile_true() as b from generate_series(1,2);
select volatile_true() or volatile_false() or stable_false() as b from generate_series(1,2);
select volatile_false() or volatile_true() or stable_false() as b from generate_series(1,2);

select stable_true() and volatile_false() and stable_false() as b from generate_series(1,2);
select stable_false() and volatile_true() and stable_true() as b from generate_series(1,2);
select stable_true() and volatile_false() as b from generate_series(1,2);
select stable_true() and stable_true() and volatile_false() as b from generate_series(1,2);
select volatile_true() and volatile_false() and stable_true() as b from generate_series(1,2);
select volatile_false() and volatile_true() and stable_true() as b from generate_series(1,2);

prepare param_test(bool) as select $1 or stable_false() or volatile_true() as b from generate_series(1,2);
execute param_test(true);
execute param_test(false);

