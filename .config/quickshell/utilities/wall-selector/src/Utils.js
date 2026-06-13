function getExtension(fileName) {
    return fileName.substring(fileName.lastIndexOf(".") + 1).toLowerCase();
}

function isVideo(fileName, filterVideos) {
    return filterVideos.indexOf(getExtension(fileName)) !== -1;
}

function isImage(fileName, filterImages) {
    return filterImages.indexOf(getExtension(fileName)) !== -1;
}

function nameFilters(filterImages, filterVideos) {
    return (filterImages || []).concat(filterVideos || []).map((ext) => "*." + ext);
}

function wallpaperCommand(entry) {
    return "awww img \"" + entry.filePath + "\" --transition-type wipe --transition-angle 30 --transition-step 90";
}
