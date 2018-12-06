component{

	remote function startCrawl(){
		urls = [
			"https://en.wikipedia.org/wiki/Adobe_ColdFusion",
			"http://www.learncfinaweek.com/week1/What_is_ColdFusion_",
			"https://www.raymondcamden.com/categories/coldfusion",
			"http://forta.com/blog/index.cfm/2008/12/14/ColdFusion-Per-Application-Settings-v2",
			"https://coldfusion.adobe.com/2018/05/coldfusion-blog-redirection-to-coldfusion-community-portal/",
			"http://cephas.net/blog/tags/coldfusion/",
			"http://blog.cfaether.com/2018/05/re-upgrade-path-to-coldfusion-2018.html"
		];

		futResAr = crawlWebPages(urls);
	}

	function crawlWebPages(urls){
		func = function(url){
			webCrawler = CreateObject("component", "WebCrawler");
			return webCrawler.crawl(url);
		}

		futArr = [];
		for(item in urls){
			futArr.append(runasync(function(){ return item}).then(func));
		}
		return futArr;
	}
}
