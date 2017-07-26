# Custom D3 Visualization
Modified from source code from [How to Make an Interactive Network Visualization](https://flowingdata.com/2012/08/02/how-to-make-an-interactive-network-visualization/)

## Setup
1. Set up a Python environment with Python 3.4
	* You can download Python 3.4.3 [here](https://www.python.org/downloads/release/python-343/) and use [virtualenv](http://python-guide-pt-br.readthedocs.io/en/latest/dev/virtualenvs/) to create an environment
	* Or you can download Anaconda [here](https://www.continuum.io/downloads) and create an environment with most of the packages installed. Navigate to the setup folder and run
	```
	conda env create -f environment.yml
	```
2. Clone or download this repo
3. Install python packages
	1. Navigate to setup folder of this repo and run 
	```
	pip install -r requirements.txt
	```
	2. Run 
	```
	pip install pygraphviz-1.3.1-cp34-none-win_amd64.whl
	```
4. Install [CasperJS](http://casperjs.org/)
  
## Usage
### Configuring the Visualization
1. You can browse graphs by running a python server. Place your dot files in data/dot. Run 
```
convertDotToJSON.cmd
```
This will generate a data.json containing the names of the json files and place the json files in a folder called json.
2. In the top directory, run runServer.cmd. This command assumes you are running Python 3 or higher. This will run a server on port 8000 by default. You may change this port number in runServer.cmd if you wish.
3. In a browser, you should be able to see the webpage at http://localhost:8000/
4. From the page, you should be able to view each json file listed in data.json. If you generate new json files, you can hard reload the page to force the browser to grab the new data.json by opening up the console and holding down the reload button.

### Generating SVG's
1. Once you've decided on the configuration, copy the link to the graph to your clipboard by clicking "Link To Graph".
2. Paste the link in the first line of data/casperSVGGen.js and save the file.
```
const exampleURL = 'http://localhost:8000/?graph=&layout=radial&movement=static&filter=all&sort=alpha&charge=1221&linkdistance=103&linkstrength=10&radius=44&layoutradius=285';
```
3. Run 
```
convertJSONToSVG.cmd
```
This will make requests to the server with each of the json files listed in data.json and save each graph to an svg in the folder svgs.