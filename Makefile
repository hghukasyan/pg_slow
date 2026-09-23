EXTENSION = pg_slow
DATA = sql/pg_slow--0.1.0.sql

REGRESS = pg_slow
REGRESS_OPTS = --temp-config=$(srcdir)/test/pg_slow.conf

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
