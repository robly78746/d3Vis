#conda install networkx
#conda install graphviz
#conda install -c conda-forge pydotplus

import networkx as nx
from networkx.readwrite import json_graph
from networkx.drawing.nx_pydot import read_dot
from networkx.drawing.nx_agraph import from_agraph

#dump json into file
import json

#get absolute filepaths
import os

#command line arguments
import sys

#file pattern matching
import glob

import graphviz
import pygraphviz as pgv
from pygraphviz.agraph import DotError

def filesWithExtensions(folderPath, extensions):
    files = []
    for extension in extensions:
        filenames = [x[x.rfind('\\') + 1:] for x in glob.glob(folderPath + '/*' + extension)]
        files.extend(filenames)
    return files
	
dotFileExtensions = ['.dot', '.gv']
dataFileName = 'data.json'

if len(sys.argv) == 3:
    dotFolderPath = os.path.abspath(sys.argv[1])
    jsonFolderPath = os.path.abspath(sys.argv[2])
    if not os.path.exists(jsonFolderPath):
        os.mkdir(jsonFolderPath)
    dotFiles = filesWithExtensions(dotFolderPath, dotFileExtensions)
    counter = 0
    for dotFile in dotFiles:
        dotFilePath = dotFolderPath + '/' + dotFile
        try:
            graph_netx = read_dot(dotFilePath)
        except (ValueError, DotError) as e:
            dot_graph = pgv.AGraph(dotFilePath)
            graph_netx = from_agraph(dot_graph)
            print(dotFile + ' not in graphviz format')
            continue
        
        graph_json = json_graph.node_link_data(graph_netx)#dot_graph)
        filename = dotFile[:dotFile.rfind('.')]
        json.dump(graph_json,open(jsonFolderPath + '/' + filename + '.json','w'),indent=2)
        print(filename + '.json converted')
        counter += 1
    with open(dataFileName, 'w') as jsonFile:
        data = {}
        jsonFiles = filesWithExtensions(jsonFolderPath, ['.json'])
        while dataFileName in jsonFiles:
            jsonFiles.remove(dataFileName)
        data["graphs"] = jsonFiles
        json.dump(data, jsonFile, indent=2)
    print('{0} dot file{1} converted'.format(counter, '' if counter == 1 else 's'))
else:
    sys.stderr.write("Syntax : python %s dot_folder json_folder\n" % sys.argv[0])