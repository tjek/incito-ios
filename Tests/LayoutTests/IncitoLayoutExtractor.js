javascript:(function(){ 
    function download(data, filename, type) {
        var file = new Blob([data], {type: type});
        if (window.navigator.msSaveOrOpenBlob)
            window.navigator.msSaveOrOpenBlob(file, filename);
        else {
            var a = document.createElement("a"),
                    url = URL.createObjectURL(file);
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            setTimeout(function() {
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);  
            }, 0); 
        }
    }

    function getRecursiveRect(element, rootViewRect) {
        const elRect = element.getBoundingClientRect();
        
        var childRects = [];
        for (childEl of element.childNodes) {
            if (childEl.classList != undefined && childEl.classList.contains("incito__view")) {
                childRects.push(getRecursiveRect(childEl, rootViewRect));
            }
        }
        var properties = {
            id: element.getAttribute("data-id"),
            rect: {
                    x: elRect.left - rootViewRect.left,
                    y: elRect.top - rootViewRect.top,
                    width: elRect.width,
                    height: elRect.height
                },
            children: childRects
        };

        return properties;
    }

    const incitoEl = document.body.getElementsByClassName('incito')[0];

    const rootView = incitoEl.firstElementChild;
    const rootViewRect = rootView.getBoundingClientRect();
    
    let nestedRects = getRecursiveRect(rootView, rootViewRect);
    let jsonStr = JSON.stringify(nestedRects, null, 2);
    
    let filename = prompt("Enter the json's filename : ", "dimensions.json");

    if (filename) {
        download(jsonStr, filename, 'text/plain');
    }
})();