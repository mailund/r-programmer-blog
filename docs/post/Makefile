
SOURCE_POSTS := $(wildcard *.Rmd)
DEST_POSTS := $(patsubst %.Rmd,%.md,$(SOURCE_POSTS))

all: $(DEST_POSTS)	

%.md: %.Rmd
	./runknitr.sh $<
