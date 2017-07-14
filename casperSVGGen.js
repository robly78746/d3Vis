var casper = require('casper').create();
casper.start('http://localhost:8000/index.html');
casper.waitForSelector('svg', function() {
	casper.wait(5000, function() {
			this.echo(this.evaluate(function(sel) {
			var s = new XMLSerializer();
			var svg = document.querySelector(sel);
			var source = s.serializeToString(svg);
			source = '<?xml version="1.0" standalone="no"?>\r\n' + source;
			return source;
		}, 'svg'));
	});
	
	},
	function fail() {
		console.log("oops");
	}
);
casper.run();

