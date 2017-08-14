#get absolute filepaths
import os
#json parsing
import json 
#file pattern matching
import glob
#command line arguments
import sys


def filesWithExtensions(folderPath, extensions):
    files = []
    for extension in extensions:
        filenames = [x[x.rfind('\\') + 1:] for x in glob.glob(folderPath + '/*' + extension)]
        files.extend(filenames)
    return files

if len(sys.argv) == 2:
	jsonFileExtension = '.json'
	jsonFolderPath = os.path.abspath(sys.argv[1])
	jsonFiles = filesWithExtensions(jsonFolderPath, [jsonFileExtension])
	typesOfNodes = set()
	for jsonFile in jsonFiles:
		with open(jsonFolderPath + '/' + jsonFile) as data_file: 
			try:
				data = json.load(data_file)
				if 'nodes' in data:
					for node in data['nodes']:
						if 'type' in node:
							typesOfNodes.add(node['type'])
			except:
				print('An error occurred when reading ' + jsonFile)
			
	print(sorted(list(typesOfNodes)))
	print("Number of types of nodes:", len(typesOfNodes))
else:
	sys.stderr.write("Syntax : python %s json_folder\n" % sys.argv[0])