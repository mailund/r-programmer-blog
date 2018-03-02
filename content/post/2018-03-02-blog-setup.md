+++
title = "Blog Setup"
date = 2018-03-02T09:48:01+01:00
tags = ["Blogdown", "Hugo"]
categories = ["Blog"]
+++

Ok, I hadn't planned to write any more about how the blog is set up, since that isn't that interesting to me and probably isn't to you — either you know a lot more about this than me, in which case I have nothing to teach you, or you just don't care, which I can relate to.

Anyway, it might help me to write this down while I still remember, in case I need to do it all again at some other time.

One of the problems I had was that GitHub wants the files it shows in its pages in one specific form while Hugo wants them in another. And [`blogdown`](https://github.com/rstudio/blogdown), which feels like the natural solution to blogging about R, wants to play with Hugo, while I am more familiar with GitHub, so wanted to use GitHub Pages rather than learning another platform.

To square this circle, I tried one solution [involving sub-branches](https://amber.rbind.io/blog/2016/12/19/creatingsite/) and another [using two separate repositories](https://tclavelle.github.io/blog/blogdown_github/). Both solutions *almost* worked, but with neither did I manage to change the theme away from the default blogdown one—and I want a simpler theme like the one I am using now.

The solution I managed stop stumble into — more through luck than skill — is simpler than either of the two above. If you add a directory called `docs` to your repository, GitHub is happy use that for your site. You just need to push the directory to GitHub and then go into Settings and select this under GitHub Pages. You cannot choose this option before you have pushed the `docs` directory, so remember to do this first.

![](https://mailund.github.io/r-programmer-blog/post/2018-03-02-purpose/2018-03-02-github-pages-setup.png)

Once that is done, you tell Hugo to put the published pages in that directory by putting

```
publishDir = "docs"
```

in your configuration file.

When I build a site using Hugo, it modifies everything under `docs` and not just the new pieces, so it introduces more traffic to GitHub than I had hoped for, but it works for now, so I dare not fiddle with it much more.

I do have to build the site using Hugo to get the base-URL set correctly. If I build the site using 

```r
blogdown::build_site()
```

The URLs are not set correctly.

It doesn't look like I can get Hugo to set the URLs correctly for images either. This is annoying since I either have to hardwire them—and then I can't see them when I use local hosting to check a post before committing it—or simply go without images. I don't even know how images are supposed to work with Hugo, to be honest, so I'm simply suffering from my ignorance now. But that is another problem for another day.
