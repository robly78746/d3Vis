const exampleURL = 'http://localhost:8000/?graph=digital_logic_template.json&layout=radial&movement=static&filter=all&sort=children&charge=1221&linkdistance=103&linkstrength=10&linkcolor=%23999999&radius=44&layoutradius=285';
var baseURLEndIndex = exampleURL.indexOf('graph=');
var configStartIndex = exampleURL.indexOf('&layout');
if (baseURLEndIndex < 0 || configStartIndex < 0)
	throw 'invalid example URL';
baseURLEndIndex += 6;
var baseURL = exampleURL.substring(0, baseURLEndIndex);
var config = exampleURL.substring(configStartIndex);
var casper = require('casper').create();
var data = require('data.json');
var fs = require('fs');
const svgDirectory = 'svgs/';
const svgFileExtension = '.svg';
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

