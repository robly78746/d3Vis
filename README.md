# Custom D3 Visualization
Modified from source code from [How to Make an Interactive Network Visualization](https://flowingdata.com/2012/08/02/how-to-make-an-interactive-network-visualization/)

## Setup
1. Set up a Python environment with Python 3.4
  * You can download Python 3.4.3 [here](https://www.python.org/downloads/release/python-343/) and use [virtualenv](http://python-guide-pt-br.readthedocs.io/en/latest/dev/virtualenvs/) to create an environment
  * Or you can download Anaconda [here](https://www.continuum.io/downloads) and create an environment with most of the packages installed. Navigate to the setup folder and run conda env create -f environment.yml.
2. Install python packages
  a. Navigate to setup folder and run pip install -r requirements.txt
  b. Run pip install pygraphviz-1.3.1-cp34-none-win_amd64.whl
3. Install [CasperJS](http://casperjs.org/)
  
## Usage
1. To configure the visualization, you can browse graphs by running a python server. Place your dot files in data/dot. Run convertDotToJSON.cmd. This will generate a data.json containing the names of the json files and place the json files in a folder called json.
2. In the top directory, run runServer.cmd. This command assumes you are running Python 3 or higher. This will run a server on port 8000 by default. You may change this port number if you wish.
3. In a browser, you should be able to see the webpage at http://localhost:8000/
