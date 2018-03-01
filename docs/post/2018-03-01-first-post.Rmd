+++
title = "First Post"
date = 2018-03-01T22:46:35+01:00
tags = ["Blogdown"]
categories = []
+++

This is my first attempt at a Hugo+Blogdown blog. I got tired of struggling with formatting R code on my [Wordpress blog](http://www.mailund.dk), so figured it would make sense to use RMarkdown to write about R code. That is what I use in my books, in any case, so I am familiar with it — and how hard can it be to set up a static page blog?

Pretty hard, as it turns out, and I still haven’t completely managed yet. I struggled for hours trying to get this Hugo blog to accept anything but the default theme once I put the pages on GitHub and more through luck than skills I eventually managed.

Oh the joy!

But then I discover that the base urls are not handled correctly. I can get those to work if I use the `hugo` command line, but not if I process the site through `blogdown`. So I ended up with a Makefile for running RMarkdown files through `knitr` to produce Markdown files.

That works well enough, but I still haven’t figured out how to get images to have the right base-url. I can work around that if I insert images manually, but this is going to annoy me when I plot from R.

Well, I’ll worry about that later. I’ve had enough trouble getting this far, so it is only fair I leave a little trouble to Future Thomas.

For now, I've wasted so much time setting this site up that I don't have any time to write about what I came here for: tail-recursion optimisation in R. So I will leave that for tomorrow.

Good night.

