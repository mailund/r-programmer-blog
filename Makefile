
all:
	(cd content/post && make)
	hugo

deploy: all
	git add .
	git commit -a -m "updating blog at `date`"
	git push
