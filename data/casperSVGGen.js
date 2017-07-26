var casper = require('casper').create();
var data = require('data.json');
var fs = require('fs');
const svgDirectory = 'svgs/';
const svgFileExtension = '.svg';
const baseURL = 'http://localhost:8000/?graph=';
var config = '&layout=radial&movement=static&filter=all&sort=alpha&charge=1221&linkdistance=103&linkstrength=10&radius=44&layoutradius=285';
casper.start();
casper.then(function() {
	var current = 0;
	var end = data.graphs.length;
	for(; current < end;) {
		(function(cntr) {
			var graphJSON = data.graphs[cntr];
			casper.thenOpen(baseURL + graphJSON + config, function() {
				casper.waitForSelector('svg', function() {
					var source = this.evaluate(function(sel) {
						var s = new XMLSerializer();
						var svg = document.querySelector(sel);
						var source = s.serializeToString(svg);
						source = '<?xml version="1.0" standalone="no"?>\r\n' + source;
						return source;
					}, 'svg');
					var indexOfFileExtension = graphJSON.indexOf(".json");
					var baseFileName = graphJSON.substring(0, indexOfFileExtension);
					svgFilePath = svgDirectory + baseFileName + svgFileExtension;
					fs.write(svgFilePath, source, 'w');
					casper.echo(svgFilePath + ' generated');
				});
			});
		})(current);
		
		current++;
	}
});
casper.run();
