#!/usr/bin/env python
import argparse
import zipfile
import os


def zip_files(zip_filename, filenames):
    zip = zipfile.ZipFile(zip_filename, "w", zipfile.ZIP_DEFLATED)
    for filename in filenames:
        if os.path.isdir(filename):
            for (walk_dirpath, walk_dirnames, walk_filenames) in os.walk(filename):
                for walk_filename in walk_filenames:
                    zip.write(os.path.join(walk_dirpath, walk_filename))
        zip.write(filename)
    zip.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("zipfilename", help="Filename for created ziip")
    parser.add_argument('filenames', metavar="filename", nargs='+',
                   help='filenames for zipping')
    args= parser.parse_args()
    zip_files(args.zipfilename, args.filenames)


if __name__ == '__main__':
    main()
