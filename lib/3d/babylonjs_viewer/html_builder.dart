import 'dart:convert' show htmlEscape;

abstract class HTMLBuilder {
  HTMLBuilder._();

  static String build(
      {final String htmlTemplate = '',
      required final String src,
      final String? functions}) {
    final html = StringBuffer(htmlTemplate);
    html.writeln("""<model url="${htmlEscape.convert(src)}"></model>""");
    html.write(
        """</babylon> <script id="viewer-template" type="text/x-babylon-viewer-template"> <style>viewer{position: relative; overflow: hidden; /* Start stage */ z-index: 1; justify-content: center; align-items: center; width: 100%; height: 100%;}.babylonjs-canvas{flex: 1; width: 100%; height: 100%; /* enable cross-browser pointer events */ touch-action: none;}</style> <canvas class="babylonjs-canvas" touch-action="none"></canvas> <nav-bar></nav-bar> </script> <script id="loading-screen" type="text/x-babylon-viewer-template"> <style>body{background-color:#000;}loading-screen{position: absolute; z-index: 100; opacity: 1; pointer-events: none; display: flex; justify-content: center; align-items: center; -webkit-transition: opacity 2s ease; -moz-transition: opacity 2s ease; transition: opacity 2s ease;}.sk-folding-cube{margin: 20px auto; width: 40px; height: 40px; position: relative; -webkit-transform: rotateZ(45deg); transform: rotateZ(45deg);}.sk-folding-cube .sk-cube{float: left; width: 50%; height: 50%; position: relative; -webkit-transform: scale(1.1); -ms-transform: scale(1.1); transform: scale(1.1);}.sk-folding-cube .sk-cube:before{content: ''; position: absolute; top: 0; left: 0; width: 100%; height: 100%; background-color: #7FC7E4; -webkit-animation: sk-foldCubeAngle 2.4s infinite linear both; animation: sk-foldCubeAngle 2.4s infinite linear both; -webkit-transform-origin: 100% 100%; -ms-transform-origin: 100% 100%; transform-origin: 100% 100%;}.sk-folding-cube .sk-cube2{-webkit-transform: scale(1.1) rotateZ(90deg); transform: scale(1.1) rotateZ(90deg);}.sk-folding-cube .sk-cube3{-webkit-transform: scale(1.1) rotateZ(180deg); transform: scale(1.1) rotateZ(180deg);}.sk-folding-cube .sk-cube4{-webkit-transform: scale(1.1) rotateZ(270deg); transform: scale(1.1) rotateZ(270deg);}.sk-folding-cube .sk-cube2:before{-webkit-animation-delay: 0.3s; animation-delay: 0.3s;}.sk-folding-cube .sk-cube3:before{-webkit-animation-delay: 0.6s; animation-delay: 0.6s;}.sk-folding-cube .sk-cube4:before{-webkit-animation-delay: 0.9s; animation-delay: 0.9s;}@-webkit-keyframes sk-foldCubeAngle{0%, 10%{-webkit-transform: perspective(140px) rotateX(-180deg); transform: perspective(140px) rotateX(-180deg); opacity: 0;}25%, 75%{-webkit-transform: perspective(140px) rotateX(0deg); transform: perspective(140px) rotateX(0deg); opacity: 1;}90%, 100%{-webkit-transform: perspective(140px) rotateY(180deg); transform: perspective(140px) rotateY(180deg); opacity: 0;}}@keyframes sk-foldCubeAngle{0%, 10%{-webkit-transform: perspective(140px) rotateX(-180deg); transform: perspective(140px) rotateX(-180deg); opacity: 0;}25%, 75%{-webkit-transform: perspective(140px) rotateX(0deg); transform: perspective(140px) rotateX(0deg); opacity: 1;}90%, 100%{-webkit-transform: perspective(140px) rotateY(180deg); transform: perspective(140px) rotateY(180deg); opacity: 0;}}</style> <div class="wrapper"> <div class="sk-folding-cube"> <div class="sk-cube1 sk-cube"></div><div class="sk-cube2 sk-cube"></div><div class="sk-cube4 sk-cube"></div><div class="sk-cube3 sk-cube"></div></div></div></script> <script src="babylon.viewer.min.js"></script><script>${functions.toString()}</script></body></html>""");
    return html.toString();
  }
}
