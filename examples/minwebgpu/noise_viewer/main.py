from os import listdir
from os.path import isfile, join, splitext

def remove_extension( path ):
    return splitext( path )[ 0 ]

noise_path = "shaders/noise"
hash_path = "shaders/hash"

noise_files = [ remove_extension( f ) for f in listdir( noise_path ) if isfile( join( noise_path, f ) ) ]
hash_files = [ remove_extension( f ) for f in listdir( hash_path ) if isfile( join( hash_path, f ) ) ]

with open( "shaders/noise_list.txt", "w") as file:
    file.write( '\n'.join( noise_files ) )

with open( "shaders/hash_list.txt", "w") as file:
    file.write( '\n'.join( hash_files ) )
