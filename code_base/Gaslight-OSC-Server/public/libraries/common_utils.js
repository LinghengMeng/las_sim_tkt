//Ip and port of the server to connect socket to
var url = window.location.href
var end = url.indexOf(":",8);
var ip = url.substring(7,end)
var serverIp = ip;
var serverPort = '3002';
var date = Date(Date.now()).toString() + " "
var theme = true // True is light, False is dark

// Socket setup
var socket;
socket = io.connect(serverIp+":"+serverPort);

// Define Socket Messages and their Corresponding function
socket.on('updateProps',updateProps);
socket.on('loginVerified',loginVerified);

//HTML GENERATION

// try and get the stylesheet link, if it doesn't exist, make it
function getStyle(){

    var style = document.getElementById("pagestyle");

    if (!style){
        var head = document.head;
        var link = document.createElement("link");

        link.type = "text/css";
        link.rel = "stylesheet";
        link.id = "pagestyle";
        link.href = "css/style.css";
      
        head.appendChild(link);
        var style = document.getElementById("pagestyle");
    }
    return style;
}

// toggles the theme
function toggleTheme(){
    var styleElement = getStyle();

    if (theme){
        styleElement.setAttribute("href", 'css/style-dark.css');
    }
    else{
        styleElement.setAttribute("href", 'css/style.css');
    }
    theme = !theme
}

// Set theme based on Time of day
function loadTheme(){
    var currentDate = new Date(Date.now())
    var currentHour = parseInt(currentDate.getHours())
    var styleElement = getStyle();

    if (currentHour < 18 && currentHour > 6){
        styleElement.setAttribute("href", 'css/style.css');
        theme = true;
    } 

    else{
        styleElement.setAttribute("href", 'css/style-dark.css');
        theme = false
    }
}

// generate a titlecard (includes theme toggle button)
function addTitleCard(){
    var title = document.title;
    var body = document.body;

    var div = document.createElement("div");
    div.className = "header";

    var headerOne = document.createElement("h1");
    headerOne.innerHTML = title;

    var themeButton = document.createElement("button");
    themeButton.addEventListener('click', function(){toggleTheme()});
    themeButton.style = "float:right; padding: 8px 8px; margin:auto; width:50px";
    themeButton.id = "themeToggle";

    var icon = document.createElement("i");
    icon.className = "fas fa-adjust";

    themeButton.appendChild(icon);
    headerOne.appendChild(themeButton);
    div.appendChild(headerOne);
    body.insertBefore(div,body.childNodes[0]);
}


//LOAD AND LOGIN

// On Load Function for all Pages
function onload(){
    verifylogin();
    socket.emit('load', 0);
    console.log(date + 'emitted load');
    loadTheme();
    addTitleCard();

    // request initial ("current") data from each behaviour
    if(!(typeof objectList === 'undefined')) {
        requestCurrentSettings();
        //requestAllPresets();
    }
}

// LOGIN VERIFICATION
function verifylogin(){
    console.log(date + window.location.search);
    socket.emit('verifyLogin', window.location.search);
}

// Login reponse
function loginVerified(bool){
    if (bool){
        console.log(date + 'login Verified');
    }
    else{
        console.log(date + 'login failed');
        console.log(window.location.pathname)
        if (window.location.pathname != '/index.html'){
            window.location = 'index.html'
        }
        
    }
}


// GENERALIZED UPDATE FUNCTION
function updateProps(data){
    for (var key in data){
        try{
            // Get All Elements with the key in their Class Name
            var elements = document.getElementsByClassName(key);

            if (elements.length == 0){
                throw String(key)
            }
            
            for (i = 0; i < elements.length; i++) {
                var element = elements[i];
                
                // Check the Elements Type and assign data as required
                if (element.nodeName == "SPAN"){
                    //Just Set Text
                    element.innerHTML = data[key]
                }

                if (element.nodeName == "INPUT"){
                    // Set Slider Value
                    if (element.type == "range"){
                        element.value = data[key]
                    }

                    // Set Radio Checked
                    if (element.type == "radio"){
                        if (element.id == (key + '-' + data[key])){
                            element.checked = true;
                        }
                    }
                }    
            }
        }
        catch(err){console.log('Unhandled Data in: ' + err)}
    }
}
