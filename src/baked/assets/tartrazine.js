var Tartrazine = (function (exports) {
  'use strict';

  var validator = {};

  var util = {};

  var hasRequiredUtil;

  function requireUtil () {
  	if (hasRequiredUtil) return util;
  	hasRequiredUtil = 1;
  	(function (exports$1) {

  		const nameStartChar = ':A-Za-z_\\u00C0-\\u00D6\\u00D8-\\u00F6\\u00F8-\\u02FF\\u0370-\\u037D\\u037F-\\u1FFF\\u200C-\\u200D\\u2070-\\u218F\\u2C00-\\u2FEF\\u3001-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFFD';
  		const nameChar = nameStartChar + '\\-.\\d\\u00B7\\u0300-\\u036F\\u203F-\\u2040';
  		const nameRegexp = '[' + nameStartChar + '][' + nameChar + ']*';
  		const regexName = new RegExp('^' + nameRegexp + '$');

  		const getAllMatches = function(string, regex) {
  		  const matches = [];
  		  let match = regex.exec(string);
  		  while (match) {
  		    const allmatches = [];
  		    allmatches.startIndex = regex.lastIndex - match[0].length;
  		    const len = match.length;
  		    for (let index = 0; index < len; index++) {
  		      allmatches.push(match[index]);
  		    }
  		    matches.push(allmatches);
  		    match = regex.exec(string);
  		  }
  		  return matches;
  		};

  		const isName = function(string) {
  		  const match = regexName.exec(string);
  		  return !(match === null || typeof match === 'undefined');
  		};

  		exports$1.isExist = function(v) {
  		  return typeof v !== 'undefined';
  		};

  		exports$1.isEmptyObject = function(obj) {
  		  return Object.keys(obj).length === 0;
  		};

  		/**
  		 * Copy all the properties of a into b.
  		 * @param {*} target
  		 * @param {*} a
  		 */
  		exports$1.merge = function(target, a, arrayMode) {
  		  if (a) {
  		    const keys = Object.keys(a); // will return an array of own properties
  		    const len = keys.length; //don't make it inline
  		    for (let i = 0; i < len; i++) {
  		      if (arrayMode === 'strict') {
  		        target[keys[i]] = [ a[keys[i]] ];
  		      } else {
  		        target[keys[i]] = a[keys[i]];
  		      }
  		    }
  		  }
  		};
  		/* exports.merge =function (b,a){
  		  return Object.assign(b,a);
  		} */

  		exports$1.getValue = function(v) {
  		  if (exports$1.isExist(v)) {
  		    return v;
  		  } else {
  		    return '';
  		  }
  		};

  		// const fakeCall = function(a) {return a;};
  		// const fakeCallNoReturn = function() {};

  		exports$1.isName = isName;
  		exports$1.getAllMatches = getAllMatches;
  		exports$1.nameRegexp = nameRegexp; 
  	} (util));
  	return util;
  }

  var hasRequiredValidator;

  function requireValidator () {
  	if (hasRequiredValidator) return validator;
  	hasRequiredValidator = 1;

  	const util = requireUtil();

  	const defaultOptions = {
  	  allowBooleanAttributes: false, //A tag can have attributes without any value
  	  unpairedTags: []
  	};

  	//const tagsPattern = new RegExp("<\\/?([\\w:\\-_\.]+)\\s*\/?>","g");
  	validator.validate = function (xmlData, options) {
  	  options = Object.assign({}, defaultOptions, options);

  	  //xmlData = xmlData.replace(/(\r\n|\n|\r)/gm,"");//make it single line
  	  //xmlData = xmlData.replace(/(^\s*<\?xml.*?\?>)/g,"");//Remove XML starting tag
  	  //xmlData = xmlData.replace(/(<!DOCTYPE[\s\w\"\.\/\-\:]+(\[.*\])*\s*>)/g,"");//Remove DOCTYPE
  	  const tags = [];
  	  let tagFound = false;

  	  //indicates that the root tag has been closed (aka. depth 0 has been reached)
  	  let reachedRoot = false;

  	  if (xmlData[0] === '\ufeff') {
  	    // check for byte order mark (BOM)
  	    xmlData = xmlData.substr(1);
  	  }
  	  
  	  for (let i = 0; i < xmlData.length; i++) {

  	    if (xmlData[i] === '<' && xmlData[i+1] === '?') {
  	      i+=2;
  	      i = readPI(xmlData,i);
  	      if (i.err) return i;
  	    }else if (xmlData[i] === '<') {
  	      //starting of tag
  	      //read until you reach to '>' avoiding any '>' in attribute value
  	      let tagStartPos = i;
  	      i++;
  	      
  	      if (xmlData[i] === '!') {
  	        i = readCommentAndCDATA(xmlData, i);
  	        continue;
  	      } else {
  	        let closingTag = false;
  	        if (xmlData[i] === '/') {
  	          //closing tag
  	          closingTag = true;
  	          i++;
  	        }
  	        //read tagname
  	        let tagName = '';
  	        for (; i < xmlData.length &&
  	          xmlData[i] !== '>' &&
  	          xmlData[i] !== ' ' &&
  	          xmlData[i] !== '\t' &&
  	          xmlData[i] !== '\n' &&
  	          xmlData[i] !== '\r'; i++
  	        ) {
  	          tagName += xmlData[i];
  	        }
  	        tagName = tagName.trim();
  	        //console.log(tagName);

  	        if (tagName[tagName.length - 1] === '/') {
  	          //self closing tag without attributes
  	          tagName = tagName.substring(0, tagName.length - 1);
  	          //continue;
  	          i--;
  	        }
  	        if (!validateTagName(tagName)) {
  	          let msg;
  	          if (tagName.trim().length === 0) {
  	            msg = "Invalid space after '<'.";
  	          } else {
  	            msg = "Tag '"+tagName+"' is an invalid name.";
  	          }
  	          return getErrorObject('InvalidTag', msg, getLineNumberForPosition(xmlData, i));
  	        }

  	        const result = readAttributeStr(xmlData, i);
  	        if (result === false) {
  	          return getErrorObject('InvalidAttr', "Attributes for '"+tagName+"' have open quote.", getLineNumberForPosition(xmlData, i));
  	        }
  	        let attrStr = result.value;
  	        i = result.index;

  	        if (attrStr[attrStr.length - 1] === '/') {
  	          //self closing tag
  	          const attrStrStart = i - attrStr.length;
  	          attrStr = attrStr.substring(0, attrStr.length - 1);
  	          const isValid = validateAttributeString(attrStr, options);
  	          if (isValid === true) {
  	            tagFound = true;
  	            //continue; //text may presents after self closing tag
  	          } else {
  	            //the result from the nested function returns the position of the error within the attribute
  	            //in order to get the 'true' error line, we need to calculate the position where the attribute begins (i - attrStr.length) and then add the position within the attribute
  	            //this gives us the absolute index in the entire xml, which we can use to find the line at last
  	            return getErrorObject(isValid.err.code, isValid.err.msg, getLineNumberForPosition(xmlData, attrStrStart + isValid.err.line));
  	          }
  	        } else if (closingTag) {
  	          if (!result.tagClosed) {
  	            return getErrorObject('InvalidTag', "Closing tag '"+tagName+"' doesn't have proper closing.", getLineNumberForPosition(xmlData, i));
  	          } else if (attrStr.trim().length > 0) {
  	            return getErrorObject('InvalidTag', "Closing tag '"+tagName+"' can't have attributes or invalid starting.", getLineNumberForPosition(xmlData, tagStartPos));
  	          } else if (tags.length === 0) {
  	            return getErrorObject('InvalidTag', "Closing tag '"+tagName+"' has not been opened.", getLineNumberForPosition(xmlData, tagStartPos));
  	          } else {
  	            const otg = tags.pop();
  	            if (tagName !== otg.tagName) {
  	              let openPos = getLineNumberForPosition(xmlData, otg.tagStartPos);
  	              return getErrorObject('InvalidTag',
  	                "Expected closing tag '"+otg.tagName+"' (opened in line "+openPos.line+", col "+openPos.col+") instead of closing tag '"+tagName+"'.",
  	                getLineNumberForPosition(xmlData, tagStartPos));
  	            }

  	            //when there are no more tags, we reached the root level.
  	            if (tags.length == 0) {
  	              reachedRoot = true;
  	            }
  	          }
  	        } else {
  	          const isValid = validateAttributeString(attrStr, options);
  	          if (isValid !== true) {
  	            //the result from the nested function returns the position of the error within the attribute
  	            //in order to get the 'true' error line, we need to calculate the position where the attribute begins (i - attrStr.length) and then add the position within the attribute
  	            //this gives us the absolute index in the entire xml, which we can use to find the line at last
  	            return getErrorObject(isValid.err.code, isValid.err.msg, getLineNumberForPosition(xmlData, i - attrStr.length + isValid.err.line));
  	          }

  	          //if the root level has been reached before ...
  	          if (reachedRoot === true) {
  	            return getErrorObject('InvalidXml', 'Multiple possible root nodes found.', getLineNumberForPosition(xmlData, i));
  	          } else if(options.unpairedTags.indexOf(tagName) !== -1); else {
  	            tags.push({tagName, tagStartPos});
  	          }
  	          tagFound = true;
  	        }

  	        //skip tag text value
  	        //It may include comments and CDATA value
  	        for (i++; i < xmlData.length; i++) {
  	          if (xmlData[i] === '<') {
  	            if (xmlData[i + 1] === '!') {
  	              //comment or CADATA
  	              i++;
  	              i = readCommentAndCDATA(xmlData, i);
  	              continue;
  	            } else if (xmlData[i+1] === '?') {
  	              i = readPI(xmlData, ++i);
  	              if (i.err) return i;
  	            } else {
  	              break;
  	            }
  	          } else if (xmlData[i] === '&') {
  	            const afterAmp = validateAmpersand(xmlData, i);
  	            if (afterAmp == -1)
  	              return getErrorObject('InvalidChar', "char '&' is not expected.", getLineNumberForPosition(xmlData, i));
  	            i = afterAmp;
  	          }else {
  	            if (reachedRoot === true && !isWhiteSpace(xmlData[i])) {
  	              return getErrorObject('InvalidXml', "Extra text at the end", getLineNumberForPosition(xmlData, i));
  	            }
  	          }
  	        } //end of reading tag text value
  	        if (xmlData[i] === '<') {
  	          i--;
  	        }
  	      }
  	    } else {
  	      if ( isWhiteSpace(xmlData[i])) {
  	        continue;
  	      }
  	      return getErrorObject('InvalidChar', "char '"+xmlData[i]+"' is not expected.", getLineNumberForPosition(xmlData, i));
  	    }
  	  }

  	  if (!tagFound) {
  	    return getErrorObject('InvalidXml', 'Start tag expected.', 1);
  	  }else if (tags.length == 1) {
  	      return getErrorObject('InvalidTag', "Unclosed tag '"+tags[0].tagName+"'.", getLineNumberForPosition(xmlData, tags[0].tagStartPos));
  	  }else if (tags.length > 0) {
  	      return getErrorObject('InvalidXml', "Invalid '"+
  	          JSON.stringify(tags.map(t => t.tagName), null, 4).replace(/\r?\n/g, '')+
  	          "' found.", {line: 1, col: 1});
  	  }

  	  return true;
  	};

  	function isWhiteSpace(char){
  	  return char === ' ' || char === '\t' || char === '\n'  || char === '\r';
  	}
  	/**
  	 * Read Processing insstructions and skip
  	 * @param {*} xmlData
  	 * @param {*} i
  	 */
  	function readPI(xmlData, i) {
  	  const start = i;
  	  for (; i < xmlData.length; i++) {
  	    if (xmlData[i] == '?' || xmlData[i] == ' ') {
  	      //tagname
  	      const tagname = xmlData.substr(start, i - start);
  	      if (i > 5 && tagname === 'xml') {
  	        return getErrorObject('InvalidXml', 'XML declaration allowed only at the start of the document.', getLineNumberForPosition(xmlData, i));
  	      } else if (xmlData[i] == '?' && xmlData[i + 1] == '>') {
  	        //check if valid attribut string
  	        i++;
  	        break;
  	      } else {
  	        continue;
  	      }
  	    }
  	  }
  	  return i;
  	}

  	function readCommentAndCDATA(xmlData, i) {
  	  if (xmlData.length > i + 5 && xmlData[i + 1] === '-' && xmlData[i + 2] === '-') {
  	    //comment
  	    for (i += 3; i < xmlData.length; i++) {
  	      if (xmlData[i] === '-' && xmlData[i + 1] === '-' && xmlData[i + 2] === '>') {
  	        i += 2;
  	        break;
  	      }
  	    }
  	  } else if (
  	    xmlData.length > i + 8 &&
  	    xmlData[i + 1] === 'D' &&
  	    xmlData[i + 2] === 'O' &&
  	    xmlData[i + 3] === 'C' &&
  	    xmlData[i + 4] === 'T' &&
  	    xmlData[i + 5] === 'Y' &&
  	    xmlData[i + 6] === 'P' &&
  	    xmlData[i + 7] === 'E'
  	  ) {
  	    let angleBracketsCount = 1;
  	    for (i += 8; i < xmlData.length; i++) {
  	      if (xmlData[i] === '<') {
  	        angleBracketsCount++;
  	      } else if (xmlData[i] === '>') {
  	        angleBracketsCount--;
  	        if (angleBracketsCount === 0) {
  	          break;
  	        }
  	      }
  	    }
  	  } else if (
  	    xmlData.length > i + 9 &&
  	    xmlData[i + 1] === '[' &&
  	    xmlData[i + 2] === 'C' &&
  	    xmlData[i + 3] === 'D' &&
  	    xmlData[i + 4] === 'A' &&
  	    xmlData[i + 5] === 'T' &&
  	    xmlData[i + 6] === 'A' &&
  	    xmlData[i + 7] === '['
  	  ) {
  	    for (i += 8; i < xmlData.length; i++) {
  	      if (xmlData[i] === ']' && xmlData[i + 1] === ']' && xmlData[i + 2] === '>') {
  	        i += 2;
  	        break;
  	      }
  	    }
  	  }

  	  return i;
  	}

  	const doubleQuote = '"';
  	const singleQuote = "'";

  	/**
  	 * Keep reading xmlData until '<' is found outside the attribute value.
  	 * @param {string} xmlData
  	 * @param {number} i
  	 */
  	function readAttributeStr(xmlData, i) {
  	  let attrStr = '';
  	  let startChar = '';
  	  let tagClosed = false;
  	  for (; i < xmlData.length; i++) {
  	    if (xmlData[i] === doubleQuote || xmlData[i] === singleQuote) {
  	      if (startChar === '') {
  	        startChar = xmlData[i];
  	      } else if (startChar !== xmlData[i]) ; else {
  	        startChar = '';
  	      }
  	    } else if (xmlData[i] === '>') {
  	      if (startChar === '') {
  	        tagClosed = true;
  	        break;
  	      }
  	    }
  	    attrStr += xmlData[i];
  	  }
  	  if (startChar !== '') {
  	    return false;
  	  }

  	  return {
  	    value: attrStr,
  	    index: i,
  	    tagClosed: tagClosed
  	  };
  	}

  	/**
  	 * Select all the attributes whether valid or invalid.
  	 */
  	const validAttrStrRegxp = new RegExp('(\\s*)([^\\s=]+)(\\s*=)?(\\s*([\'"])(([\\s\\S])*?)\\5)?', 'g');

  	//attr, ="sd", a="amit's", a="sd"b="saf", ab  cd=""

  	function validateAttributeString(attrStr, options) {
  	  //console.log("start:"+attrStr+":end");

  	  //if(attrStr.trim().length === 0) return true; //empty string

  	  const matches = util.getAllMatches(attrStr, validAttrStrRegxp);
  	  const attrNames = {};

  	  for (let i = 0; i < matches.length; i++) {
  	    if (matches[i][1].length === 0) {
  	      //nospace before attribute name: a="sd"b="saf"
  	      return getErrorObject('InvalidAttr', "Attribute '"+matches[i][2]+"' has no space in starting.", getPositionFromMatch(matches[i]))
  	    } else if (matches[i][3] !== undefined && matches[i][4] === undefined) {
  	      return getErrorObject('InvalidAttr', "Attribute '"+matches[i][2]+"' is without value.", getPositionFromMatch(matches[i]));
  	    } else if (matches[i][3] === undefined && !options.allowBooleanAttributes) {
  	      //independent attribute: ab
  	      return getErrorObject('InvalidAttr', "boolean attribute '"+matches[i][2]+"' is not allowed.", getPositionFromMatch(matches[i]));
  	    }
  	    /* else if(matches[i][6] === undefined){//attribute without value: ab=
  	                    return { err: { code:"InvalidAttr",msg:"attribute " + matches[i][2] + " has no value assigned."}};
  	                } */
  	    const attrName = matches[i][2];
  	    if (!validateAttrName(attrName)) {
  	      return getErrorObject('InvalidAttr', "Attribute '"+attrName+"' is an invalid name.", getPositionFromMatch(matches[i]));
  	    }
  	    if (!attrNames.hasOwnProperty(attrName)) {
  	      //check for duplicate attribute.
  	      attrNames[attrName] = 1;
  	    } else {
  	      return getErrorObject('InvalidAttr', "Attribute '"+attrName+"' is repeated.", getPositionFromMatch(matches[i]));
  	    }
  	  }

  	  return true;
  	}

  	function validateNumberAmpersand(xmlData, i) {
  	  let re = /\d/;
  	  if (xmlData[i] === 'x') {
  	    i++;
  	    re = /[\da-fA-F]/;
  	  }
  	  for (; i < xmlData.length; i++) {
  	    if (xmlData[i] === ';')
  	      return i;
  	    if (!xmlData[i].match(re))
  	      break;
  	  }
  	  return -1;
  	}

  	function validateAmpersand(xmlData, i) {
  	  // https://www.w3.org/TR/xml/#dt-charref
  	  i++;
  	  if (xmlData[i] === ';')
  	    return -1;
  	  if (xmlData[i] === '#') {
  	    i++;
  	    return validateNumberAmpersand(xmlData, i);
  	  }
  	  let count = 0;
  	  for (; i < xmlData.length; i++, count++) {
  	    if (xmlData[i].match(/\w/) && count < 20)
  	      continue;
  	    if (xmlData[i] === ';')
  	      break;
  	    return -1;
  	  }
  	  return i;
  	}

  	function getErrorObject(code, message, lineNumber) {
  	  return {
  	    err: {
  	      code: code,
  	      msg: message,
  	      line: lineNumber.line || lineNumber,
  	      col: lineNumber.col,
  	    },
  	  };
  	}

  	function validateAttrName(attrName) {
  	  return util.isName(attrName);
  	}

  	// const startsWithXML = /^xml/i;

  	function validateTagName(tagname) {
  	  return util.isName(tagname) /* && !tagname.match(startsWithXML) */;
  	}

  	//this function returns the line number for the character at the given index
  	function getLineNumberForPosition(xmlData, index) {
  	  const lines = xmlData.substring(0, index).split(/\r?\n/);
  	  return {
  	    line: lines.length,

  	    // column number is last line's length + 1, because column numbering starts at 1:
  	    col: lines[lines.length - 1].length + 1
  	  };
  	}

  	//this function returns the position of the first character of match within attrStr
  	function getPositionFromMatch(match) {
  	  return match.startIndex + match[1].length;
  	}
  	return validator;
  }

  var OptionsBuilder = {};

  var hasRequiredOptionsBuilder;

  function requireOptionsBuilder () {
  	if (hasRequiredOptionsBuilder) return OptionsBuilder;
  	hasRequiredOptionsBuilder = 1;
  	const defaultOptions = {
  	    preserveOrder: false,
  	    attributeNamePrefix: '@_',
  	    attributesGroupName: false,
  	    textNodeName: '#text',
  	    ignoreAttributes: true,
  	    removeNSPrefix: false, // remove NS from tag name or attribute name if true
  	    allowBooleanAttributes: false, //a tag can have attributes without any value
  	    //ignoreRootElement : false,
  	    parseTagValue: true,
  	    parseAttributeValue: false,
  	    trimValues: true, //Trim string values of tag and attributes
  	    cdataPropName: false,
  	    numberParseOptions: {
  	      hex: true,
  	      leadingZeros: true,
  	      eNotation: true
  	    },
  	    tagValueProcessor: function(tagName, val) {
  	      return val;
  	    },
  	    attributeValueProcessor: function(attrName, val) {
  	      return val;
  	    },
  	    stopNodes: [], //nested tags will not be parsed even for errors
  	    alwaysCreateTextNode: false,
  	    isArray: () => false,
  	    commentPropName: false,
  	    unpairedTags: [],
  	    processEntities: true,
  	    htmlEntities: false,
  	    ignoreDeclaration: false,
  	    ignorePiTags: false,
  	    transformTagName: false,
  	    transformAttributeName: false,
  	    updateTag: function(tagName, jPath, attrs){
  	      return tagName
  	    },
  	    // skipEmptyListItem: false
  	};
  	   
  	const buildOptions = function(options) {
  	    return Object.assign({}, defaultOptions, options);
  	};

  	OptionsBuilder.buildOptions = buildOptions;
  	OptionsBuilder.defaultOptions = defaultOptions;
  	return OptionsBuilder;
  }

  var xmlNode;
  var hasRequiredXmlNode;

  function requireXmlNode () {
  	if (hasRequiredXmlNode) return xmlNode;
  	hasRequiredXmlNode = 1;

  	class XmlNode{
  	  constructor(tagname) {
  	    this.tagname = tagname;
  	    this.child = []; //nested tags, text, cdata, comments in order
  	    this[":@"] = {}; //attributes map
  	  }
  	  add(key,val){
  	    // this.child.push( {name : key, val: val, isCdata: isCdata });
  	    if(key === "__proto__") key = "#__proto__";
  	    this.child.push( {[key]: val });
  	  }
  	  addChild(node) {
  	    if(node.tagname === "__proto__") node.tagname = "#__proto__";
  	    if(node[":@"] && Object.keys(node[":@"]).length > 0){
  	      this.child.push( { [node.tagname]: node.child, [":@"]: node[":@"] });
  	    }else {
  	      this.child.push( { [node.tagname]: node.child });
  	    }
  	  };
  	}

  	xmlNode = XmlNode;
  	return xmlNode;
  }

  var DocTypeReader;
  var hasRequiredDocTypeReader;

  function requireDocTypeReader () {
  	if (hasRequiredDocTypeReader) return DocTypeReader;
  	hasRequiredDocTypeReader = 1;
  	const util = requireUtil();

  	//TODO: handle comments
  	function readDocType(xmlData, i){
  	    
  	    const entities = {};
  	    if( xmlData[i + 3] === 'O' &&
  	         xmlData[i + 4] === 'C' &&
  	         xmlData[i + 5] === 'T' &&
  	         xmlData[i + 6] === 'Y' &&
  	         xmlData[i + 7] === 'P' &&
  	         xmlData[i + 8] === 'E')
  	    {    
  	        i = i+9;
  	        let angleBracketsCount = 1;
  	        let hasBody = false, comment = false;
  	        let exp = "";
  	        for(;i<xmlData.length;i++){
  	            if (xmlData[i] === '<' && !comment) { //Determine the tag type
  	                if( hasBody && isEntity(xmlData, i)){
  	                    i += 7; 
  	                    let entityName, val;
  	                    [entityName, val,i] = readEntityExp(xmlData,i+1);
  	                    if(val.indexOf("&") === -1) //Parameter entities are not supported
  	                        entities[ validateEntityName(entityName) ] = {
  	                            regx : RegExp( `&${entityName};`,"g"),
  	                            val: val
  	                        };
  	                }
  	                else if( hasBody && isElement(xmlData, i))  i += 8;//Not supported
  	                else if( hasBody && isAttlist(xmlData, i))  i += 8;//Not supported
  	                else if( hasBody && isNotation(xmlData, i)) i += 9;//Not supported
  	                else if( isComment)                         comment = true;
  	                else                                        throw new Error("Invalid DOCTYPE");

  	                angleBracketsCount++;
  	                exp = "";
  	            } else if (xmlData[i] === '>') { //Read tag content
  	                if(comment){
  	                    if( xmlData[i - 1] === "-" && xmlData[i - 2] === "-"){
  	                        comment = false;
  	                        angleBracketsCount--;
  	                    }
  	                }else {
  	                    angleBracketsCount--;
  	                }
  	                if (angleBracketsCount === 0) {
  	                  break;
  	                }
  	            }else if( xmlData[i] === '['){
  	                hasBody = true;
  	            }else {
  	                exp += xmlData[i];
  	            }
  	        }
  	        if(angleBracketsCount !== 0){
  	            throw new Error(`Unclosed DOCTYPE`);
  	        }
  	    }else {
  	        throw new Error(`Invalid Tag instead of DOCTYPE`);
  	    }
  	    return {entities, i};
  	}

  	function readEntityExp(xmlData,i){
  	    //External entities are not supported
  	    //    <!ENTITY ext SYSTEM "http://normal-website.com" >

  	    //Parameter entities are not supported
  	    //    <!ENTITY entityname "&anotherElement;">

  	    //Internal entities are supported
  	    //    <!ENTITY entityname "replacement text">
  	    
  	    //read EntityName
  	    let entityName = "";
  	    for (; i < xmlData.length && (xmlData[i] !== "'" && xmlData[i] !== '"' ); i++) {
  	        // if(xmlData[i] === " ") continue;
  	        // else 
  	        entityName += xmlData[i];
  	    }
  	    entityName = entityName.trim();
  	    if(entityName.indexOf(" ") !== -1) throw new Error("External entites are not supported");

  	    //read Entity Value
  	    const startChar = xmlData[i++];
  	    let val = "";
  	    for (; i < xmlData.length && xmlData[i] !== startChar ; i++) {
  	        val += xmlData[i];
  	    }
  	    return [entityName, val, i];
  	}

  	function isComment(xmlData, i){
  	    if(xmlData[i+1] === '!' &&
  	    xmlData[i+2] === '-' &&
  	    xmlData[i+3] === '-') return true
  	    return false
  	}
  	function isEntity(xmlData, i){
  	    if(xmlData[i+1] === '!' &&
  	    xmlData[i+2] === 'E' &&
  	    xmlData[i+3] === 'N' &&
  	    xmlData[i+4] === 'T' &&
  	    xmlData[i+5] === 'I' &&
  	    xmlData[i+6] === 'T' &&
  	    xmlData[i+7] === 'Y') return true
  	    return false
  	}
  	function isElement(xmlData, i){
  	    if(xmlData[i+1] === '!' &&
  	    xmlData[i+2] === 'E' &&
  	    xmlData[i+3] === 'L' &&
  	    xmlData[i+4] === 'E' &&
  	    xmlData[i+5] === 'M' &&
  	    xmlData[i+6] === 'E' &&
  	    xmlData[i+7] === 'N' &&
  	    xmlData[i+8] === 'T') return true
  	    return false
  	}

  	function isAttlist(xmlData, i){
  	    if(xmlData[i+1] === '!' &&
  	    xmlData[i+2] === 'A' &&
  	    xmlData[i+3] === 'T' &&
  	    xmlData[i+4] === 'T' &&
  	    xmlData[i+5] === 'L' &&
  	    xmlData[i+6] === 'I' &&
  	    xmlData[i+7] === 'S' &&
  	    xmlData[i+8] === 'T') return true
  	    return false
  	}
  	function isNotation(xmlData, i){
  	    if(xmlData[i+1] === '!' &&
  	    xmlData[i+2] === 'N' &&
  	    xmlData[i+3] === 'O' &&
  	    xmlData[i+4] === 'T' &&
  	    xmlData[i+5] === 'A' &&
  	    xmlData[i+6] === 'T' &&
  	    xmlData[i+7] === 'I' &&
  	    xmlData[i+8] === 'O' &&
  	    xmlData[i+9] === 'N') return true
  	    return false
  	}

  	function validateEntityName(name){
  	    if (util.isName(name))
  		return name;
  	    else
  	        throw new Error(`Invalid entity name ${name}`);
  	}

  	DocTypeReader = readDocType;
  	return DocTypeReader;
  }

  var strnum;
  var hasRequiredStrnum;

  function requireStrnum () {
  	if (hasRequiredStrnum) return strnum;
  	hasRequiredStrnum = 1;
  	const hexRegex = /^[-+]?0x[a-fA-F0-9]+$/;
  	const numRegex = /^([\-\+])?(0*)([0-9]*(\.[0-9]*)?)$/;
  	// const octRegex = /^0x[a-z0-9]+/;
  	// const binRegex = /0x[a-z0-9]+/;

  	 
  	const consider = {
  	    hex :  true,
  	    // oct: false,
  	    leadingZeros: true,
  	    decimalPoint: "\.",
  	    eNotation: true,
  	    //skipLike: /regex/
  	};

  	function toNumber(str, options = {}){
  	    options = Object.assign({}, consider, options );
  	    if(!str || typeof str !== "string" ) return str;
  	    
  	    let trimmedStr  = str.trim();
  	    
  	    if(options.skipLike !== undefined && options.skipLike.test(trimmedStr)) return str;
  	    else if(str==="0") return 0;
  	    else if (options.hex && hexRegex.test(trimmedStr)) {
  	        return parse_int(trimmedStr, 16);
  	    // }else if (options.oct && octRegex.test(str)) {
  	    //     return Number.parseInt(val, 8);
  	    }else if (trimmedStr.search(/[eE]/)!== -1) { //eNotation
  	        const notation = trimmedStr.match(/^([-\+])?(0*)([0-9]*(\.[0-9]*)?[eE][-\+]?[0-9]+)$/); 
  	        // +00.123 => [ , '+', '00', '.123', ..
  	        if(notation){
  	            // console.log(notation)
  	            if(options.leadingZeros){ //accept with leading zeros
  	                trimmedStr = (notation[1] || "") + notation[3];
  	            }else {
  	                if(notation[2] === "0" && notation[3][0]=== ".");else {
  	                    return str;
  	                }
  	            }
  	            return options.eNotation ? Number(trimmedStr) : str;
  	        }else {
  	            return str;
  	        }
  	    // }else if (options.parseBin && binRegex.test(str)) {
  	    //     return Number.parseInt(val, 2);
  	    }else {
  	        //separate negative sign, leading zeros, and rest number
  	        const match = numRegex.exec(trimmedStr);
  	        // +00.123 => [ , '+', '00', '.123', ..
  	        if(match){
  	            const sign = match[1];
  	            const leadingZeros = match[2];
  	            let numTrimmedByZeros = trimZeros(match[3]); //complete num without leading zeros
  	            //trim ending zeros for floating number
  	            
  	            if(!options.leadingZeros && leadingZeros.length > 0 && sign && trimmedStr[2] !== ".") return str; //-0123
  	            else if(!options.leadingZeros && leadingZeros.length > 0 && !sign && trimmedStr[1] !== ".") return str; //0123
  	            else if(options.leadingZeros && leadingZeros===str) return 0; //00
  	            
  	            else {//no leading zeros or leading zeros are allowed
  	                const num = Number(trimmedStr);
  	                const numStr = "" + num;

  	                if(numStr.search(/[eE]/) !== -1){ //given number is long and parsed to eNotation
  	                    if(options.eNotation) return num;
  	                    else return str;
  	                }else if(trimmedStr.indexOf(".") !== -1){ //floating number
  	                    if(numStr === "0" && (numTrimmedByZeros === "") ) return num; //0.0
  	                    else if(numStr === numTrimmedByZeros) return num; //0.456. 0.79000
  	                    else if( sign && numStr === "-"+numTrimmedByZeros) return num;
  	                    else return str;
  	                }
  	                
  	                if(leadingZeros){
  	                    return (numTrimmedByZeros === numStr) || (sign+numTrimmedByZeros === numStr) ? num : str
  	                }else  {
  	                    return (trimmedStr === numStr) || (trimmedStr === sign+numStr) ? num : str
  	                }
  	            }
  	        }else { //non-numeric string
  	            return str;
  	        }
  	    }
  	}

  	/**
  	 * 
  	 * @param {string} numStr without leading zeros
  	 * @returns 
  	 */
  	function trimZeros(numStr){
  	    if(numStr && numStr.indexOf(".") !== -1){//float
  	        numStr = numStr.replace(/0+$/, ""); //remove ending zeros
  	        if(numStr === ".")  numStr = "0";
  	        else if(numStr[0] === ".")  numStr = "0"+numStr;
  	        else if(numStr[numStr.length-1] === ".")  numStr = numStr.substr(0,numStr.length-1);
  	        return numStr;
  	    }
  	    return numStr;
  	}

  	function parse_int(numStr, base){
  	    //polyfill
  	    if(parseInt) return parseInt(numStr, base);
  	    else if(Number.parseInt) return Number.parseInt(numStr, base);
  	    else if(window && window.parseInt) return window.parseInt(numStr, base);
  	    else throw new Error("parseInt, Number.parseInt, window.parseInt are not supported")
  	}

  	strnum = toNumber;
  	return strnum;
  }

  var ignoreAttributes;
  var hasRequiredIgnoreAttributes;

  function requireIgnoreAttributes () {
  	if (hasRequiredIgnoreAttributes) return ignoreAttributes;
  	hasRequiredIgnoreAttributes = 1;
  	function getIgnoreAttributesFn(ignoreAttributes) {
  	    if (typeof ignoreAttributes === 'function') {
  	        return ignoreAttributes
  	    }
  	    if (Array.isArray(ignoreAttributes)) {
  	        return (attrName) => {
  	            for (const pattern of ignoreAttributes) {
  	                if (typeof pattern === 'string' && attrName === pattern) {
  	                    return true
  	                }
  	                if (pattern instanceof RegExp && pattern.test(attrName)) {
  	                    return true
  	                }
  	            }
  	        }
  	    }
  	    return () => false
  	}

  	ignoreAttributes = getIgnoreAttributesFn;
  	return ignoreAttributes;
  }

  var OrderedObjParser_1;
  var hasRequiredOrderedObjParser;

  function requireOrderedObjParser () {
  	if (hasRequiredOrderedObjParser) return OrderedObjParser_1;
  	hasRequiredOrderedObjParser = 1;
  	///@ts-check

  	const util = requireUtil();
  	const xmlNode = requireXmlNode();
  	const readDocType = requireDocTypeReader();
  	const toNumber = requireStrnum();
  	const getIgnoreAttributesFn = requireIgnoreAttributes();

  	// const regx =
  	//   '<((!\\[CDATA\\[([\\s\\S]*?)(]]>))|((NAME:)?(NAME))([^>]*)>|((\\/)(NAME)\\s*>))([^<]*)'
  	//   .replace(/NAME/g, util.nameRegexp);

  	//const tagsRegx = new RegExp("<(\\/?[\\w:\\-\._]+)([^>]*)>(\\s*"+cdataRegx+")*([^<]+)?","g");
  	//const tagsRegx = new RegExp("<(\\/?)((\\w*:)?([\\w:\\-\._]+))([^>]*)>([^<]*)("+cdataRegx+"([^<]*))*([^<]+)?","g");

  	class OrderedObjParser{
  	  constructor(options){
  	    this.options = options;
  	    this.currentNode = null;
  	    this.tagsNodeStack = [];
  	    this.docTypeEntities = {};
  	    this.lastEntities = {
  	      "apos" : { regex: /&(apos|#39|#x27);/g, val : "'"},
  	      "gt" : { regex: /&(gt|#62|#x3E);/g, val : ">"},
  	      "lt" : { regex: /&(lt|#60|#x3C);/g, val : "<"},
  	      "quot" : { regex: /&(quot|#34|#x22);/g, val : "\""},
  	    };
  	    this.ampEntity = { regex: /&(amp|#38|#x26);/g, val : "&"};
  	    this.htmlEntities = {
  	      "space": { regex: /&(nbsp|#160);/g, val: " " },
  	      // "lt" : { regex: /&(lt|#60);/g, val: "<" },
  	      // "gt" : { regex: /&(gt|#62);/g, val: ">" },
  	      // "amp" : { regex: /&(amp|#38);/g, val: "&" },
  	      // "quot" : { regex: /&(quot|#34);/g, val: "\"" },
  	      // "apos" : { regex: /&(apos|#39);/g, val: "'" },
  	      "cent" : { regex: /&(cent|#162);/g, val: "¢" },
  	      "pound" : { regex: /&(pound|#163);/g, val: "£" },
  	      "yen" : { regex: /&(yen|#165);/g, val: "¥" },
  	      "euro" : { regex: /&(euro|#8364);/g, val: "€" },
  	      "copyright" : { regex: /&(copy|#169);/g, val: "©" },
  	      "reg" : { regex: /&(reg|#174);/g, val: "®" },
  	      "inr" : { regex: /&(inr|#8377);/g, val: "₹" },
  	      "num_dec": { regex: /&#([0-9]{1,7});/g, val : (_, str) => String.fromCharCode(Number.parseInt(str, 10)) },
  	      "num_hex": { regex: /&#x([0-9a-fA-F]{1,6});/g, val : (_, str) => String.fromCharCode(Number.parseInt(str, 16)) },
  	    };
  	    this.addExternalEntities = addExternalEntities;
  	    this.parseXml = parseXml;
  	    this.parseTextData = parseTextData;
  	    this.resolveNameSpace = resolveNameSpace;
  	    this.buildAttributesMap = buildAttributesMap;
  	    this.isItStopNode = isItStopNode;
  	    this.replaceEntitiesValue = replaceEntitiesValue;
  	    this.readStopNodeData = readStopNodeData;
  	    this.saveTextToParentTag = saveTextToParentTag;
  	    this.addChild = addChild;
  	    this.ignoreAttributesFn = getIgnoreAttributesFn(this.options.ignoreAttributes);
  	  }

  	}

  	function addExternalEntities(externalEntities){
  	  const entKeys = Object.keys(externalEntities);
  	  for (let i = 0; i < entKeys.length; i++) {
  	    const ent = entKeys[i];
  	    this.lastEntities[ent] = {
  	       regex: new RegExp("&"+ent+";","g"),
  	       val : externalEntities[ent]
  	    };
  	  }
  	}

  	/**
  	 * @param {string} val
  	 * @param {string} tagName
  	 * @param {string} jPath
  	 * @param {boolean} dontTrim
  	 * @param {boolean} hasAttributes
  	 * @param {boolean} isLeafNode
  	 * @param {boolean} escapeEntities
  	 */
  	function parseTextData(val, tagName, jPath, dontTrim, hasAttributes, isLeafNode, escapeEntities) {
  	  if (val !== undefined) {
  	    if (this.options.trimValues && !dontTrim) {
  	      val = val.trim();
  	    }
  	    if(val.length > 0){
  	      if(!escapeEntities) val = this.replaceEntitiesValue(val);
  	      
  	      const newval = this.options.tagValueProcessor(tagName, val, jPath, hasAttributes, isLeafNode);
  	      if(newval === null || newval === undefined){
  	        //don't parse
  	        return val;
  	      }else if(typeof newval !== typeof val || newval !== val){
  	        //overwrite
  	        return newval;
  	      }else if(this.options.trimValues){
  	        return parseValue(val, this.options.parseTagValue, this.options.numberParseOptions);
  	      }else {
  	        const trimmedVal = val.trim();
  	        if(trimmedVal === val){
  	          return parseValue(val, this.options.parseTagValue, this.options.numberParseOptions);
  	        }else {
  	          return val;
  	        }
  	      }
  	    }
  	  }
  	}

  	function resolveNameSpace(tagname) {
  	  if (this.options.removeNSPrefix) {
  	    const tags = tagname.split(':');
  	    const prefix = tagname.charAt(0) === '/' ? '/' : '';
  	    if (tags[0] === 'xmlns') {
  	      return '';
  	    }
  	    if (tags.length === 2) {
  	      tagname = prefix + tags[1];
  	    }
  	  }
  	  return tagname;
  	}

  	//TODO: change regex to capture NS
  	//const attrsRegx = new RegExp("([\\w\\-\\.\\:]+)\\s*=\\s*(['\"])((.|\n)*?)\\2","gm");
  	const attrsRegx = new RegExp('([^\\s=]+)\\s*(=\\s*([\'"])([\\s\\S]*?)\\3)?', 'gm');

  	function buildAttributesMap(attrStr, jPath, tagName) {
  	  if (this.options.ignoreAttributes !== true && typeof attrStr === 'string') {
  	    // attrStr = attrStr.replace(/\r?\n/g, ' ');
  	    //attrStr = attrStr || attrStr.trim();

  	    const matches = util.getAllMatches(attrStr, attrsRegx);
  	    const len = matches.length; //don't make it inline
  	    const attrs = {};
  	    for (let i = 0; i < len; i++) {
  	      const attrName = this.resolveNameSpace(matches[i][1]);
  	      if (this.ignoreAttributesFn(attrName, jPath)) {
  	        continue
  	      }
  	      let oldVal = matches[i][4];
  	      let aName = this.options.attributeNamePrefix + attrName;
  	      if (attrName.length) {
  	        if (this.options.transformAttributeName) {
  	          aName = this.options.transformAttributeName(aName);
  	        }
  	        if(aName === "__proto__") aName  = "#__proto__";
  	        if (oldVal !== undefined) {
  	          if (this.options.trimValues) {
  	            oldVal = oldVal.trim();
  	          }
  	          oldVal = this.replaceEntitiesValue(oldVal);
  	          const newVal = this.options.attributeValueProcessor(attrName, oldVal, jPath);
  	          if(newVal === null || newVal === undefined){
  	            //don't parse
  	            attrs[aName] = oldVal;
  	          }else if(typeof newVal !== typeof oldVal || newVal !== oldVal){
  	            //overwrite
  	            attrs[aName] = newVal;
  	          }else {
  	            //parse
  	            attrs[aName] = parseValue(
  	              oldVal,
  	              this.options.parseAttributeValue,
  	              this.options.numberParseOptions
  	            );
  	          }
  	        } else if (this.options.allowBooleanAttributes) {
  	          attrs[aName] = true;
  	        }
  	      }
  	    }
  	    if (!Object.keys(attrs).length) {
  	      return;
  	    }
  	    if (this.options.attributesGroupName) {
  	      const attrCollection = {};
  	      attrCollection[this.options.attributesGroupName] = attrs;
  	      return attrCollection;
  	    }
  	    return attrs
  	  }
  	}

  	const parseXml = function(xmlData) {
  	  xmlData = xmlData.replace(/\r\n?/g, "\n"); //TODO: remove this line
  	  const xmlObj = new xmlNode('!xml');
  	  let currentNode = xmlObj;
  	  let textData = "";
  	  let jPath = "";
  	  for(let i=0; i< xmlData.length; i++){//for each char in XML data
  	    const ch = xmlData[i];
  	    if(ch === '<'){
  	      // const nextIndex = i+1;
  	      // const _2ndChar = xmlData[nextIndex];
  	      if( xmlData[i+1] === '/') {//Closing Tag
  	        const closeIndex = findClosingIndex(xmlData, ">", i, "Closing Tag is not closed.");
  	        let tagName = xmlData.substring(i+2,closeIndex).trim();

  	        if(this.options.removeNSPrefix){
  	          const colonIndex = tagName.indexOf(":");
  	          if(colonIndex !== -1){
  	            tagName = tagName.substr(colonIndex+1);
  	          }
  	        }

  	        if(this.options.transformTagName) {
  	          tagName = this.options.transformTagName(tagName);
  	        }

  	        if(currentNode){
  	          textData = this.saveTextToParentTag(textData, currentNode, jPath);
  	        }

  	        //check if last tag of nested tag was unpaired tag
  	        const lastTagName = jPath.substring(jPath.lastIndexOf(".")+1);
  	        if(tagName && this.options.unpairedTags.indexOf(tagName) !== -1 ){
  	          throw new Error(`Unpaired tag can not be used as closing tag: </${tagName}>`);
  	        }
  	        let propIndex = 0;
  	        if(lastTagName && this.options.unpairedTags.indexOf(lastTagName) !== -1 ){
  	          propIndex = jPath.lastIndexOf('.', jPath.lastIndexOf('.')-1);
  	          this.tagsNodeStack.pop();
  	        }else {
  	          propIndex = jPath.lastIndexOf(".");
  	        }
  	        jPath = jPath.substring(0, propIndex);

  	        currentNode = this.tagsNodeStack.pop();//avoid recursion, set the parent tag scope
  	        textData = "";
  	        i = closeIndex;
  	      } else if( xmlData[i+1] === '?') {

  	        let tagData = readTagExp(xmlData,i, false, "?>");
  	        if(!tagData) throw new Error("Pi Tag is not closed.");

  	        textData = this.saveTextToParentTag(textData, currentNode, jPath);
  	        if( (this.options.ignoreDeclaration && tagData.tagName === "?xml") || this.options.ignorePiTags);else {
  	  
  	          const childNode = new xmlNode(tagData.tagName);
  	          childNode.add(this.options.textNodeName, "");
  	          
  	          if(tagData.tagName !== tagData.tagExp && tagData.attrExpPresent){
  	            childNode[":@"] = this.buildAttributesMap(tagData.tagExp, jPath, tagData.tagName);
  	          }
  	          this.addChild(currentNode, childNode, jPath);

  	        }


  	        i = tagData.closeIndex + 1;
  	      } else if(xmlData.substr(i + 1, 3) === '!--') {
  	        const endIndex = findClosingIndex(xmlData, "-->", i+4, "Comment is not closed.");
  	        if(this.options.commentPropName){
  	          const comment = xmlData.substring(i + 4, endIndex - 2);

  	          textData = this.saveTextToParentTag(textData, currentNode, jPath);

  	          currentNode.add(this.options.commentPropName, [ { [this.options.textNodeName] : comment } ]);
  	        }
  	        i = endIndex;
  	      } else if( xmlData.substr(i + 1, 2) === '!D') {
  	        const result = readDocType(xmlData, i);
  	        this.docTypeEntities = result.entities;
  	        i = result.i;
  	      }else if(xmlData.substr(i + 1, 2) === '![') {
  	        const closeIndex = findClosingIndex(xmlData, "]]>", i, "CDATA is not closed.") - 2;
  	        const tagExp = xmlData.substring(i + 9,closeIndex);

  	        textData = this.saveTextToParentTag(textData, currentNode, jPath);

  	        let val = this.parseTextData(tagExp, currentNode.tagname, jPath, true, false, true, true);
  	        if(val == undefined) val = "";

  	        //cdata should be set even if it is 0 length string
  	        if(this.options.cdataPropName){
  	          currentNode.add(this.options.cdataPropName, [ { [this.options.textNodeName] : tagExp } ]);
  	        }else {
  	          currentNode.add(this.options.textNodeName, val);
  	        }
  	        
  	        i = closeIndex + 2;
  	      }else {//Opening tag
  	        let result = readTagExp(xmlData,i, this.options.removeNSPrefix);
  	        let tagName= result.tagName;
  	        const rawTagName = result.rawTagName;
  	        let tagExp = result.tagExp;
  	        let attrExpPresent = result.attrExpPresent;
  	        let closeIndex = result.closeIndex;

  	        if (this.options.transformTagName) {
  	          tagName = this.options.transformTagName(tagName);
  	        }
  	        
  	        //save text as child node
  	        if (currentNode && textData) {
  	          if(currentNode.tagname !== '!xml'){
  	            //when nested tag is found
  	            textData = this.saveTextToParentTag(textData, currentNode, jPath, false);
  	          }
  	        }

  	        //check if last tag was unpaired tag
  	        const lastTag = currentNode;
  	        if(lastTag && this.options.unpairedTags.indexOf(lastTag.tagname) !== -1 ){
  	          currentNode = this.tagsNodeStack.pop();
  	          jPath = jPath.substring(0, jPath.lastIndexOf("."));
  	        }
  	        if(tagName !== xmlObj.tagname){
  	          jPath += jPath ? "." + tagName : tagName;
  	        }
  	        if (this.isItStopNode(this.options.stopNodes, jPath, tagName)) {
  	          let tagContent = "";
  	          //self-closing tag
  	          if(tagExp.length > 0 && tagExp.lastIndexOf("/") === tagExp.length - 1){
  	            if(tagName[tagName.length - 1] === "/"){ //remove trailing '/'
  	              tagName = tagName.substr(0, tagName.length - 1);
  	              jPath = jPath.substr(0, jPath.length - 1);
  	              tagExp = tagName;
  	            }else {
  	              tagExp = tagExp.substr(0, tagExp.length - 1);
  	            }
  	            i = result.closeIndex;
  	          }
  	          //unpaired tag
  	          else if(this.options.unpairedTags.indexOf(tagName) !== -1){
  	            
  	            i = result.closeIndex;
  	          }
  	          //normal tag
  	          else {
  	            //read until closing tag is found
  	            const result = this.readStopNodeData(xmlData, rawTagName, closeIndex + 1);
  	            if(!result) throw new Error(`Unexpected end of ${rawTagName}`);
  	            i = result.i;
  	            tagContent = result.tagContent;
  	          }

  	          const childNode = new xmlNode(tagName);
  	          if(tagName !== tagExp && attrExpPresent){
  	            childNode[":@"] = this.buildAttributesMap(tagExp, jPath, tagName);
  	          }
  	          if(tagContent) {
  	            tagContent = this.parseTextData(tagContent, tagName, jPath, true, attrExpPresent, true, true);
  	          }
  	          
  	          jPath = jPath.substr(0, jPath.lastIndexOf("."));
  	          childNode.add(this.options.textNodeName, tagContent);
  	          
  	          this.addChild(currentNode, childNode, jPath);
  	        }else {
  	  //selfClosing tag
  	          if(tagExp.length > 0 && tagExp.lastIndexOf("/") === tagExp.length - 1){
  	            if(tagName[tagName.length - 1] === "/"){ //remove trailing '/'
  	              tagName = tagName.substr(0, tagName.length - 1);
  	              jPath = jPath.substr(0, jPath.length - 1);
  	              tagExp = tagName;
  	            }else {
  	              tagExp = tagExp.substr(0, tagExp.length - 1);
  	            }
  	            
  	            if(this.options.transformTagName) {
  	              tagName = this.options.transformTagName(tagName);
  	            }

  	            const childNode = new xmlNode(tagName);
  	            if(tagName !== tagExp && attrExpPresent){
  	              childNode[":@"] = this.buildAttributesMap(tagExp, jPath, tagName);
  	            }
  	            this.addChild(currentNode, childNode, jPath);
  	            jPath = jPath.substr(0, jPath.lastIndexOf("."));
  	          }
  	    //opening tag
  	          else {
  	            const childNode = new xmlNode( tagName);
  	            this.tagsNodeStack.push(currentNode);
  	            
  	            if(tagName !== tagExp && attrExpPresent){
  	              childNode[":@"] = this.buildAttributesMap(tagExp, jPath, tagName);
  	            }
  	            this.addChild(currentNode, childNode, jPath);
  	            currentNode = childNode;
  	          }
  	          textData = "";
  	          i = closeIndex;
  	        }
  	      }
  	    }else {
  	      textData += xmlData[i];
  	    }
  	  }
  	  return xmlObj.child;
  	};

  	function addChild(currentNode, childNode, jPath){
  	  const result = this.options.updateTag(childNode.tagname, jPath, childNode[":@"]);
  	  if(result === false);else if(typeof result === "string"){
  	    childNode.tagname = result;
  	    currentNode.addChild(childNode);
  	  }else {
  	    currentNode.addChild(childNode);
  	  }
  	}

  	const replaceEntitiesValue = function(val){

  	  if(this.options.processEntities){
  	    for(let entityName in this.docTypeEntities){
  	      const entity = this.docTypeEntities[entityName];
  	      val = val.replace( entity.regx, entity.val);
  	    }
  	    for(let entityName in this.lastEntities){
  	      const entity = this.lastEntities[entityName];
  	      val = val.replace( entity.regex, entity.val);
  	    }
  	    if(this.options.htmlEntities){
  	      for(let entityName in this.htmlEntities){
  	        const entity = this.htmlEntities[entityName];
  	        val = val.replace( entity.regex, entity.val);
  	      }
  	    }
  	    val = val.replace( this.ampEntity.regex, this.ampEntity.val);
  	  }
  	  return val;
  	};
  	function saveTextToParentTag(textData, currentNode, jPath, isLeafNode) {
  	  if (textData) { //store previously collected data as textNode
  	    if(isLeafNode === undefined) isLeafNode = currentNode.child.length === 0;
  	    
  	    textData = this.parseTextData(textData,
  	      currentNode.tagname,
  	      jPath,
  	      false,
  	      currentNode[":@"] ? Object.keys(currentNode[":@"]).length !== 0 : false,
  	      isLeafNode);

  	    if (textData !== undefined && textData !== "")
  	      currentNode.add(this.options.textNodeName, textData);
  	    textData = "";
  	  }
  	  return textData;
  	}

  	//TODO: use jPath to simplify the logic
  	/**
  	 * 
  	 * @param {string[]} stopNodes 
  	 * @param {string} jPath
  	 * @param {string} currentTagName 
  	 */
  	function isItStopNode(stopNodes, jPath, currentTagName){
  	  const allNodesExp = "*." + currentTagName;
  	  for (const stopNodePath in stopNodes) {
  	    const stopNodeExp = stopNodes[stopNodePath];
  	    if( allNodesExp === stopNodeExp || jPath === stopNodeExp  ) return true;
  	  }
  	  return false;
  	}

  	/**
  	 * Returns the tag Expression and where it is ending handling single-double quotes situation
  	 * @param {string} xmlData 
  	 * @param {number} i starting index
  	 * @returns 
  	 */
  	function tagExpWithClosingIndex(xmlData, i, closingChar = ">"){
  	  let attrBoundary;
  	  let tagExp = "";
  	  for (let index = i; index < xmlData.length; index++) {
  	    let ch = xmlData[index];
  	    if (attrBoundary) {
  	        if (ch === attrBoundary) attrBoundary = "";//reset
  	    } else if (ch === '"' || ch === "'") {
  	        attrBoundary = ch;
  	    } else if (ch === closingChar[0]) {
  	      if(closingChar[1]){
  	        if(xmlData[index + 1] === closingChar[1]){
  	          return {
  	            data: tagExp,
  	            index: index
  	          }
  	        }
  	      }else {
  	        return {
  	          data: tagExp,
  	          index: index
  	        }
  	      }
  	    } else if (ch === '\t') {
  	      ch = " ";
  	    }
  	    tagExp += ch;
  	  }
  	}

  	function findClosingIndex(xmlData, str, i, errMsg){
  	  const closingIndex = xmlData.indexOf(str, i);
  	  if(closingIndex === -1){
  	    throw new Error(errMsg)
  	  }else {
  	    return closingIndex + str.length - 1;
  	  }
  	}

  	function readTagExp(xmlData,i, removeNSPrefix, closingChar = ">"){
  	  const result = tagExpWithClosingIndex(xmlData, i+1, closingChar);
  	  if(!result) return;
  	  let tagExp = result.data;
  	  const closeIndex = result.index;
  	  const separatorIndex = tagExp.search(/\s/);
  	  let tagName = tagExp;
  	  let attrExpPresent = true;
  	  if(separatorIndex !== -1){//separate tag name and attributes expression
  	    tagName = tagExp.substring(0, separatorIndex);
  	    tagExp = tagExp.substring(separatorIndex + 1).trimStart();
  	  }

  	  const rawTagName = tagName;
  	  if(removeNSPrefix){
  	    const colonIndex = tagName.indexOf(":");
  	    if(colonIndex !== -1){
  	      tagName = tagName.substr(colonIndex+1);
  	      attrExpPresent = tagName !== result.data.substr(colonIndex + 1);
  	    }
  	  }

  	  return {
  	    tagName: tagName,
  	    tagExp: tagExp,
  	    closeIndex: closeIndex,
  	    attrExpPresent: attrExpPresent,
  	    rawTagName: rawTagName,
  	  }
  	}
  	/**
  	 * find paired tag for a stop node
  	 * @param {string} xmlData 
  	 * @param {string} tagName 
  	 * @param {number} i 
  	 */
  	function readStopNodeData(xmlData, tagName, i){
  	  const startIndex = i;
  	  // Starting at 1 since we already have an open tag
  	  let openTagCount = 1;

  	  for (; i < xmlData.length; i++) {
  	    if( xmlData[i] === "<"){ 
  	      if (xmlData[i+1] === "/") {//close tag
  	          const closeIndex = findClosingIndex(xmlData, ">", i, `${tagName} is not closed`);
  	          let closeTagName = xmlData.substring(i+2,closeIndex).trim();
  	          if(closeTagName === tagName){
  	            openTagCount--;
  	            if (openTagCount === 0) {
  	              return {
  	                tagContent: xmlData.substring(startIndex, i),
  	                i : closeIndex
  	              }
  	            }
  	          }
  	          i=closeIndex;
  	        } else if(xmlData[i+1] === '?') { 
  	          const closeIndex = findClosingIndex(xmlData, "?>", i+1, "StopNode is not closed.");
  	          i=closeIndex;
  	        } else if(xmlData.substr(i + 1, 3) === '!--') { 
  	          const closeIndex = findClosingIndex(xmlData, "-->", i+3, "StopNode is not closed.");
  	          i=closeIndex;
  	        } else if(xmlData.substr(i + 1, 2) === '![') { 
  	          const closeIndex = findClosingIndex(xmlData, "]]>", i, "StopNode is not closed.") - 2;
  	          i=closeIndex;
  	        } else {
  	          const tagData = readTagExp(xmlData, i, '>');

  	          if (tagData) {
  	            const openTagName = tagData && tagData.tagName;
  	            if (openTagName === tagName && tagData.tagExp[tagData.tagExp.length-1] !== "/") {
  	              openTagCount++;
  	            }
  	            i=tagData.closeIndex;
  	          }
  	        }
  	      }
  	  }//end for loop
  	}

  	function parseValue(val, shouldParse, options) {
  	  if (shouldParse && typeof val === 'string') {
  	    //console.log(options)
  	    const newval = val.trim();
  	    if(newval === 'true' ) return true;
  	    else if(newval === 'false' ) return false;
  	    else return toNumber(val, options);
  	  } else {
  	    if (util.isExist(val)) {
  	      return val;
  	    } else {
  	      return '';
  	    }
  	  }
  	}


  	OrderedObjParser_1 = OrderedObjParser;
  	return OrderedObjParser_1;
  }

  var node2json = {};

  var hasRequiredNode2json;

  function requireNode2json () {
  	if (hasRequiredNode2json) return node2json;
  	hasRequiredNode2json = 1;

  	/**
  	 * 
  	 * @param {array} node 
  	 * @param {any} options 
  	 * @returns 
  	 */
  	function prettify(node, options){
  	  return compress( node, options);
  	}

  	/**
  	 * 
  	 * @param {array} arr 
  	 * @param {object} options 
  	 * @param {string} jPath 
  	 * @returns object
  	 */
  	function compress(arr, options, jPath){
  	  let text;
  	  const compressedObj = {};
  	  for (let i = 0; i < arr.length; i++) {
  	    const tagObj = arr[i];
  	    const property = propName(tagObj);
  	    let newJpath = "";
  	    if(jPath === undefined) newJpath = property;
  	    else newJpath = jPath + "." + property;

  	    if(property === options.textNodeName){
  	      if(text === undefined) text = tagObj[property];
  	      else text += "" + tagObj[property];
  	    }else if(property === undefined){
  	      continue;
  	    }else if(tagObj[property]){
  	      
  	      let val = compress(tagObj[property], options, newJpath);
  	      const isLeaf = isLeafTag(val, options);

  	      if(tagObj[":@"]){
  	        assignAttributes( val, tagObj[":@"], newJpath, options);
  	      }else if(Object.keys(val).length === 1 && val[options.textNodeName] !== undefined && !options.alwaysCreateTextNode){
  	        val = val[options.textNodeName];
  	      }else if(Object.keys(val).length === 0){
  	        if(options.alwaysCreateTextNode) val[options.textNodeName] = "";
  	        else val = "";
  	      }

  	      if(compressedObj[property] !== undefined && compressedObj.hasOwnProperty(property)) {
  	        if(!Array.isArray(compressedObj[property])) {
  	            compressedObj[property] = [ compressedObj[property] ];
  	        }
  	        compressedObj[property].push(val);
  	      }else {
  	        //TODO: if a node is not an array, then check if it should be an array
  	        //also determine if it is a leaf node
  	        if (options.isArray(property, newJpath, isLeaf )) {
  	          compressedObj[property] = [val];
  	        }else {
  	          compressedObj[property] = val;
  	        }
  	      }
  	    }
  	    
  	  }
  	  // if(text && text.length > 0) compressedObj[options.textNodeName] = text;
  	  if(typeof text === "string"){
  	    if(text.length > 0) compressedObj[options.textNodeName] = text;
  	  }else if(text !== undefined) compressedObj[options.textNodeName] = text;
  	  return compressedObj;
  	}

  	function propName(obj){
  	  const keys = Object.keys(obj);
  	  for (let i = 0; i < keys.length; i++) {
  	    const key = keys[i];
  	    if(key !== ":@") return key;
  	  }
  	}

  	function assignAttributes(obj, attrMap, jpath, options){
  	  if (attrMap) {
  	    const keys = Object.keys(attrMap);
  	    const len = keys.length; //don't make it inline
  	    for (let i = 0; i < len; i++) {
  	      const atrrName = keys[i];
  	      if (options.isArray(atrrName, jpath + "." + atrrName, true, true)) {
  	        obj[atrrName] = [ attrMap[atrrName] ];
  	      } else {
  	        obj[atrrName] = attrMap[atrrName];
  	      }
  	    }
  	  }
  	}

  	function isLeafTag(obj, options){
  	  const { textNodeName } = options;
  	  const propCount = Object.keys(obj).length;
  	  
  	  if (propCount === 0) {
  	    return true;
  	  }

  	  if (
  	    propCount === 1 &&
  	    (obj[textNodeName] || typeof obj[textNodeName] === "boolean" || obj[textNodeName] === 0)
  	  ) {
  	    return true;
  	  }

  	  return false;
  	}
  	node2json.prettify = prettify;
  	return node2json;
  }

  var XMLParser_1;
  var hasRequiredXMLParser;

  function requireXMLParser () {
  	if (hasRequiredXMLParser) return XMLParser_1;
  	hasRequiredXMLParser = 1;
  	const { buildOptions} = requireOptionsBuilder();
  	const OrderedObjParser = requireOrderedObjParser();
  	const { prettify} = requireNode2json();
  	const validator = requireValidator();

  	class XMLParser{
  	    
  	    constructor(options){
  	        this.externalEntities = {};
  	        this.options = buildOptions(options);
  	        
  	    }
  	    /**
  	     * Parse XML dats to JS object 
  	     * @param {string|Buffer} xmlData 
  	     * @param {boolean|Object} validationOption 
  	     */
  	    parse(xmlData,validationOption){
  	        if(typeof xmlData === "string");else if( xmlData.toString){
  	            xmlData = xmlData.toString();
  	        }else {
  	            throw new Error("XML data is accepted in String or Bytes[] form.")
  	        }
  	        if( validationOption){
  	            if(validationOption === true) validationOption = {}; //validate with default options
  	            
  	            const result = validator.validate(xmlData, validationOption);
  	            if (result !== true) {
  	              throw Error( `${result.err.msg}:${result.err.line}:${result.err.col}` )
  	            }
  	          }
  	        const orderedObjParser = new OrderedObjParser(this.options);
  	        orderedObjParser.addExternalEntities(this.externalEntities);
  	        const orderedResult = orderedObjParser.parseXml(xmlData);
  	        if(this.options.preserveOrder || orderedResult === undefined) return orderedResult;
  	        else return prettify(orderedResult, this.options);
  	    }

  	    /**
  	     * Add Entity which is not by default supported by this library
  	     * @param {string} key 
  	     * @param {string} value 
  	     */
  	    addEntity(key, value){
  	        if(value.indexOf("&") !== -1){
  	            throw new Error("Entity value can't have '&'")
  	        }else if(key.indexOf("&") !== -1 || key.indexOf(";") !== -1){
  	            throw new Error("An entity must be set without '&' and ';'. Eg. use '#xD' for '&#xD;'")
  	        }else if(value === "&"){
  	            throw new Error("An entity with value '&' is not permitted");
  	        }else {
  	            this.externalEntities[key] = value;
  	        }
  	    }
  	}

  	XMLParser_1 = XMLParser;
  	return XMLParser_1;
  }

  var orderedJs2Xml;
  var hasRequiredOrderedJs2Xml;

  function requireOrderedJs2Xml () {
  	if (hasRequiredOrderedJs2Xml) return orderedJs2Xml;
  	hasRequiredOrderedJs2Xml = 1;
  	const EOL = "\n";

  	/**
  	 * 
  	 * @param {array} jArray 
  	 * @param {any} options 
  	 * @returns 
  	 */
  	function toXml(jArray, options) {
  	    let indentation = "";
  	    if (options.format && options.indentBy.length > 0) {
  	        indentation = EOL;
  	    }
  	    return arrToStr(jArray, options, "", indentation);
  	}

  	function arrToStr(arr, options, jPath, indentation) {
  	    let xmlStr = "";
  	    let isPreviousElementTag = false;

  	    for (let i = 0; i < arr.length; i++) {
  	        const tagObj = arr[i];
  	        const tagName = propName(tagObj);
  	        if(tagName === undefined) continue;

  	        let newJPath = "";
  	        if (jPath.length === 0) newJPath = tagName;
  	        else newJPath = `${jPath}.${tagName}`;

  	        if (tagName === options.textNodeName) {
  	            let tagText = tagObj[tagName];
  	            if (!isStopNode(newJPath, options)) {
  	                tagText = options.tagValueProcessor(tagName, tagText);
  	                tagText = replaceEntitiesValue(tagText, options);
  	            }
  	            if (isPreviousElementTag) {
  	                xmlStr += indentation;
  	            }
  	            xmlStr += tagText;
  	            isPreviousElementTag = false;
  	            continue;
  	        } else if (tagName === options.cdataPropName) {
  	            if (isPreviousElementTag) {
  	                xmlStr += indentation;
  	            }
  	            xmlStr += `<![CDATA[${tagObj[tagName][0][options.textNodeName]}]]>`;
  	            isPreviousElementTag = false;
  	            continue;
  	        } else if (tagName === options.commentPropName) {
  	            xmlStr += indentation + `<!--${tagObj[tagName][0][options.textNodeName]}-->`;
  	            isPreviousElementTag = true;
  	            continue;
  	        } else if (tagName[0] === "?") {
  	            const attStr = attr_to_str(tagObj[":@"], options);
  	            const tempInd = tagName === "?xml" ? "" : indentation;
  	            let piTextNodeName = tagObj[tagName][0][options.textNodeName];
  	            piTextNodeName = piTextNodeName.length !== 0 ? " " + piTextNodeName : ""; //remove extra spacing
  	            xmlStr += tempInd + `<${tagName}${piTextNodeName}${attStr}?>`;
  	            isPreviousElementTag = true;
  	            continue;
  	        }
  	        let newIdentation = indentation;
  	        if (newIdentation !== "") {
  	            newIdentation += options.indentBy;
  	        }
  	        const attStr = attr_to_str(tagObj[":@"], options);
  	        const tagStart = indentation + `<${tagName}${attStr}`;
  	        const tagValue = arrToStr(tagObj[tagName], options, newJPath, newIdentation);
  	        if (options.unpairedTags.indexOf(tagName) !== -1) {
  	            if (options.suppressUnpairedNode) xmlStr += tagStart + ">";
  	            else xmlStr += tagStart + "/>";
  	        } else if ((!tagValue || tagValue.length === 0) && options.suppressEmptyNode) {
  	            xmlStr += tagStart + "/>";
  	        } else if (tagValue && tagValue.endsWith(">")) {
  	            xmlStr += tagStart + `>${tagValue}${indentation}</${tagName}>`;
  	        } else {
  	            xmlStr += tagStart + ">";
  	            if (tagValue && indentation !== "" && (tagValue.includes("/>") || tagValue.includes("</"))) {
  	                xmlStr += indentation + options.indentBy + tagValue + indentation;
  	            } else {
  	                xmlStr += tagValue;
  	            }
  	            xmlStr += `</${tagName}>`;
  	        }
  	        isPreviousElementTag = true;
  	    }

  	    return xmlStr;
  	}

  	function propName(obj) {
  	    const keys = Object.keys(obj);
  	    for (let i = 0; i < keys.length; i++) {
  	        const key = keys[i];
  	        if(!obj.hasOwnProperty(key)) continue;
  	        if (key !== ":@") return key;
  	    }
  	}

  	function attr_to_str(attrMap, options) {
  	    let attrStr = "";
  	    if (attrMap && !options.ignoreAttributes) {
  	        for (let attr in attrMap) {
  	            if(!attrMap.hasOwnProperty(attr)) continue;
  	            let attrVal = options.attributeValueProcessor(attr, attrMap[attr]);
  	            attrVal = replaceEntitiesValue(attrVal, options);
  	            if (attrVal === true && options.suppressBooleanAttributes) {
  	                attrStr += ` ${attr.substr(options.attributeNamePrefix.length)}`;
  	            } else {
  	                attrStr += ` ${attr.substr(options.attributeNamePrefix.length)}="${attrVal}"`;
  	            }
  	        }
  	    }
  	    return attrStr;
  	}

  	function isStopNode(jPath, options) {
  	    jPath = jPath.substr(0, jPath.length - options.textNodeName.length - 1);
  	    let tagName = jPath.substr(jPath.lastIndexOf(".") + 1);
  	    for (let index in options.stopNodes) {
  	        if (options.stopNodes[index] === jPath || options.stopNodes[index] === "*." + tagName) return true;
  	    }
  	    return false;
  	}

  	function replaceEntitiesValue(textValue, options) {
  	    if (textValue && textValue.length > 0 && options.processEntities) {
  	        for (let i = 0; i < options.entities.length; i++) {
  	            const entity = options.entities[i];
  	            textValue = textValue.replace(entity.regex, entity.val);
  	        }
  	    }
  	    return textValue;
  	}
  	orderedJs2Xml = toXml;
  	return orderedJs2Xml;
  }

  var json2xml;
  var hasRequiredJson2xml;

  function requireJson2xml () {
  	if (hasRequiredJson2xml) return json2xml;
  	hasRequiredJson2xml = 1;
  	//parse Empty Node as self closing node
  	const buildFromOrderedJs = requireOrderedJs2Xml();
  	const getIgnoreAttributesFn = requireIgnoreAttributes();

  	const defaultOptions = {
  	  attributeNamePrefix: '@_',
  	  attributesGroupName: false,
  	  textNodeName: '#text',
  	  ignoreAttributes: true,
  	  cdataPropName: false,
  	  format: false,
  	  indentBy: '  ',
  	  suppressEmptyNode: false,
  	  suppressUnpairedNode: true,
  	  suppressBooleanAttributes: true,
  	  tagValueProcessor: function(key, a) {
  	    return a;
  	  },
  	  attributeValueProcessor: function(attrName, a) {
  	    return a;
  	  },
  	  preserveOrder: false,
  	  commentPropName: false,
  	  unpairedTags: [],
  	  entities: [
  	    { regex: new RegExp("&", "g"), val: "&amp;" },//it must be on top
  	    { regex: new RegExp(">", "g"), val: "&gt;" },
  	    { regex: new RegExp("<", "g"), val: "&lt;" },
  	    { regex: new RegExp("\'", "g"), val: "&apos;" },
  	    { regex: new RegExp("\"", "g"), val: "&quot;" }
  	  ],
  	  processEntities: true,
  	  stopNodes: [],
  	  // transformTagName: false,
  	  // transformAttributeName: false,
  	  oneListGroup: false
  	};

  	function Builder(options) {
  	  this.options = Object.assign({}, defaultOptions, options);
  	  if (this.options.ignoreAttributes === true || this.options.attributesGroupName) {
  	    this.isAttribute = function(/*a*/) {
  	      return false;
  	    };
  	  } else {
  	    this.ignoreAttributesFn = getIgnoreAttributesFn(this.options.ignoreAttributes);
  	    this.attrPrefixLen = this.options.attributeNamePrefix.length;
  	    this.isAttribute = isAttribute;
  	  }

  	  this.processTextOrObjNode = processTextOrObjNode;

  	  if (this.options.format) {
  	    this.indentate = indentate;
  	    this.tagEndChar = '>\n';
  	    this.newLine = '\n';
  	  } else {
  	    this.indentate = function() {
  	      return '';
  	    };
  	    this.tagEndChar = '>';
  	    this.newLine = '';
  	  }
  	}

  	Builder.prototype.build = function(jObj) {
  	  if(this.options.preserveOrder){
  	    return buildFromOrderedJs(jObj, this.options);
  	  }else {
  	    if(Array.isArray(jObj) && this.options.arrayNodeName && this.options.arrayNodeName.length > 1){
  	      jObj = {
  	        [this.options.arrayNodeName] : jObj
  	      };
  	    }
  	    return this.j2x(jObj, 0, []).val;
  	  }
  	};

  	Builder.prototype.j2x = function(jObj, level, ajPath) {
  	  let attrStr = '';
  	  let val = '';
  	  const jPath = ajPath.join('.');
  	  for (let key in jObj) {
  	    if(!Object.prototype.hasOwnProperty.call(jObj, key)) continue;
  	    if (typeof jObj[key] === 'undefined') {
  	      // supress undefined node only if it is not an attribute
  	      if (this.isAttribute(key)) {
  	        val += '';
  	      }
  	    } else if (jObj[key] === null) {
  	      // null attribute should be ignored by the attribute list, but should not cause the tag closing
  	      if (this.isAttribute(key)) {
  	        val += '';
  	      } else if (key === this.options.cdataPropName) {
  	        val += '';
  	      } else if (key[0] === '?') {
  	        val += this.indentate(level) + '<' + key + '?' + this.tagEndChar;
  	      } else {
  	        val += this.indentate(level) + '<' + key + '/' + this.tagEndChar;
  	      }
  	      // val += this.indentate(level) + '<' + key + '/' + this.tagEndChar;
  	    } else if (jObj[key] instanceof Date) {
  	      val += this.buildTextValNode(jObj[key], key, '', level);
  	    } else if (typeof jObj[key] !== 'object') {
  	      //premitive type
  	      const attr = this.isAttribute(key);
  	      if (attr && !this.ignoreAttributesFn(attr, jPath)) {
  	        attrStr += this.buildAttrPairStr(attr, '' + jObj[key]);
  	      } else if (!attr) {
  	        //tag value
  	        if (key === this.options.textNodeName) {
  	          let newval = this.options.tagValueProcessor(key, '' + jObj[key]);
  	          val += this.replaceEntitiesValue(newval);
  	        } else {
  	          val += this.buildTextValNode(jObj[key], key, '', level);
  	        }
  	      }
  	    } else if (Array.isArray(jObj[key])) {
  	      //repeated nodes
  	      const arrLen = jObj[key].length;
  	      let listTagVal = "";
  	      let listTagAttr = "";
  	      for (let j = 0; j < arrLen; j++) {
  	        const item = jObj[key][j];
  	        if (typeof item === 'undefined') ; else if (item === null) {
  	          if(key[0] === "?") val += this.indentate(level) + '<' + key + '?' + this.tagEndChar;
  	          else val += this.indentate(level) + '<' + key + '/' + this.tagEndChar;
  	          // val += this.indentate(level) + '<' + key + '/' + this.tagEndChar;
  	        } else if (typeof item === 'object') {
  	          if(this.options.oneListGroup){
  	            const result = this.j2x(item, level + 1, ajPath.concat(key));
  	            listTagVal += result.val;
  	            if (this.options.attributesGroupName && item.hasOwnProperty(this.options.attributesGroupName)) {
  	              listTagAttr += result.attrStr;
  	            }
  	          }else {
  	            listTagVal += this.processTextOrObjNode(item, key, level, ajPath);
  	          }
  	        } else {
  	          if (this.options.oneListGroup) {
  	            let textValue = this.options.tagValueProcessor(key, item);
  	            textValue = this.replaceEntitiesValue(textValue);
  	            listTagVal += textValue;
  	          } else {
  	            listTagVal += this.buildTextValNode(item, key, '', level);
  	          }
  	        }
  	      }
  	      if(this.options.oneListGroup){
  	        listTagVal = this.buildObjectNode(listTagVal, key, listTagAttr, level);
  	      }
  	      val += listTagVal;
  	    } else {
  	      //nested node
  	      if (this.options.attributesGroupName && key === this.options.attributesGroupName) {
  	        const Ks = Object.keys(jObj[key]);
  	        const L = Ks.length;
  	        for (let j = 0; j < L; j++) {
  	          attrStr += this.buildAttrPairStr(Ks[j], '' + jObj[key][Ks[j]]);
  	        }
  	      } else {
  	        val += this.processTextOrObjNode(jObj[key], key, level, ajPath);
  	      }
  	    }
  	  }
  	  return {attrStr: attrStr, val: val};
  	};

  	Builder.prototype.buildAttrPairStr = function(attrName, val){
  	  val = this.options.attributeValueProcessor(attrName, '' + val);
  	  val = this.replaceEntitiesValue(val);
  	  if (this.options.suppressBooleanAttributes && val === "true") {
  	    return ' ' + attrName;
  	  } else return ' ' + attrName + '="' + val + '"';
  	};

  	function processTextOrObjNode (object, key, level, ajPath) {
  	  const result = this.j2x(object, level + 1, ajPath.concat(key));
  	  if (object[this.options.textNodeName] !== undefined && Object.keys(object).length === 1) {
  	    return this.buildTextValNode(object[this.options.textNodeName], key, result.attrStr, level);
  	  } else {
  	    return this.buildObjectNode(result.val, key, result.attrStr, level);
  	  }
  	}

  	Builder.prototype.buildObjectNode = function(val, key, attrStr, level) {
  	  if(val === ""){
  	    if(key[0] === "?") return  this.indentate(level) + '<' + key + attrStr+ '?' + this.tagEndChar;
  	    else {
  	      return this.indentate(level) + '<' + key + attrStr + this.closeTag(key) + this.tagEndChar;
  	    }
  	  }else {

  	    let tagEndExp = '</' + key + this.tagEndChar;
  	    let piClosingChar = "";
  	    
  	    if(key[0] === "?") {
  	      piClosingChar = "?";
  	      tagEndExp = "";
  	    }
  	  
  	    // attrStr is an empty string in case the attribute came as undefined or null
  	    if ((attrStr || attrStr === '') && val.indexOf('<') === -1) {
  	      return ( this.indentate(level) + '<' +  key + attrStr + piClosingChar + '>' + val + tagEndExp );
  	    } else if (this.options.commentPropName !== false && key === this.options.commentPropName && piClosingChar.length === 0) {
  	      return this.indentate(level) + `<!--${val}-->` + this.newLine;
  	    }else {
  	      return (
  	        this.indentate(level) + '<' + key + attrStr + piClosingChar + this.tagEndChar +
  	        val +
  	        this.indentate(level) + tagEndExp    );
  	    }
  	  }
  	};

  	Builder.prototype.closeTag = function(key){
  	  let closeTag = "";
  	  if(this.options.unpairedTags.indexOf(key) !== -1){ //unpaired
  	    if(!this.options.suppressUnpairedNode) closeTag = "/";
  	  }else if(this.options.suppressEmptyNode){ //empty
  	    closeTag = "/";
  	  }else {
  	    closeTag = `></${key}`;
  	  }
  	  return closeTag;
  	};

  	Builder.prototype.buildTextValNode = function(val, key, attrStr, level) {
  	  if (this.options.cdataPropName !== false && key === this.options.cdataPropName) {
  	    return this.indentate(level) + `<![CDATA[${val}]]>` +  this.newLine;
  	  }else if (this.options.commentPropName !== false && key === this.options.commentPropName) {
  	    return this.indentate(level) + `<!--${val}-->` +  this.newLine;
  	  }else if(key[0] === "?") {//PI tag
  	    return  this.indentate(level) + '<' + key + attrStr+ '?' + this.tagEndChar; 
  	  }else {
  	    let textValue = this.options.tagValueProcessor(key, val);
  	    textValue = this.replaceEntitiesValue(textValue);
  	  
  	    if( textValue === ''){
  	      return this.indentate(level) + '<' + key + attrStr + this.closeTag(key) + this.tagEndChar;
  	    }else {
  	      return this.indentate(level) + '<' + key + attrStr + '>' +
  	         textValue +
  	        '</' + key + this.tagEndChar;
  	    }
  	  }
  	};

  	Builder.prototype.replaceEntitiesValue = function(textValue){
  	  if(textValue && textValue.length > 0 && this.options.processEntities){
  	    for (let i=0; i<this.options.entities.length; i++) {
  	      const entity = this.options.entities[i];
  	      textValue = textValue.replace(entity.regex, entity.val);
  	    }
  	  }
  	  return textValue;
  	};

  	function indentate(level) {
  	  return this.options.indentBy.repeat(level);
  	}

  	function isAttribute(name /*, options*/) {
  	  if (name.startsWith(this.options.attributeNamePrefix) && name !== this.options.textNodeName) {
  	    return name.substr(this.attrPrefixLen);
  	  } else {
  	    return false;
  	  }
  	}

  	json2xml = Builder;
  	return json2xml;
  }

  var fxp;
  var hasRequiredFxp;

  function requireFxp () {
  	if (hasRequiredFxp) return fxp;
  	hasRequiredFxp = 1;

  	const validator = requireValidator();
  	const XMLParser = requireXMLParser();
  	const XMLBuilder = requireJson2xml();

  	fxp = {
  	  XMLParser: XMLParser,
  	  XMLValidator: validator,
  	  XMLBuilder: XMLBuilder
  	};
  	return fxp;
  }

  var fxpExports = requireFxp();

  // fs replaced with fetch for browser
  const parser = new fxpExports.XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '',
    textNodeName: '#text',
    trimValues: false,
  });

  /**
   * Detect if running in browser environment
   */
  const isBrowser = typeof window !== 'undefined';

  /**
   * Get the base URL for loading assets
   * In browser, can be configured via setAssetBase()
   * Defaults to relative paths
   */
  function getAssetBase() {
    if (isBrowser && window.__tartrazine_asset_base) {
      return window.__tartrazine_asset_base;
    }
    return '';
  }

  /**
   * Load XML file content
   * Uses fetch() in browser, fs in Node.js
   * @param {string} path - Path to XML file
   * @returns {Promise<string>} XML content
   */
  async function loadXmlFile(path) {
    const fullPath = getAssetBase() + path;

    if (isBrowser) {
      const response = await fetch(fullPath);
      if (!response.ok) {
        throw new Error(`Failed to load ${path}: ${response.statusText}`);
      }
      return await response.text();
    } else {
      throw new Error('Cannot load local files in browser. Use loadLexer() which uses fetch() instead.');
    }
  }

  /**
   * Load and parse a lexer XML file
   * @param {string} lexerName - Name of the lexer (e.g., 'bash')
   * @returns {Promise<Object>} Parsed lexer definition
   */
  async function loadLexer(lexerName) {
    // Use the synced lexers directory for deployment/packaging
    // URL-encode the lexer name to handle special characters like # in C#
    const encodedLexerName = encodeURIComponent(lexerName);
    const xmlPath = `lexers/${encodedLexerName}.xml`;
    const xmlContent = await loadXmlFile(xmlPath);

    // Preprocess XML to handle duplicate attributes in <combined> and <push> elements
    // fast-xml-parser doesn't preserve duplicate attributes, so we need to
    // convert <combined state="a" state="b"/> to <combined state="a,b"/>
    // and <push state="a" state="b"/> to <push state="a,b"/>
    let preprocessed = xmlContent.replace(
      /<(combined|push)\s+([^>]*?)>/g,
      (match, tagName, attrs) => {
        // Extract all state attributes
        const stateRegex = /state="([^"]+)"/g;
        const states = [];
        let stateMatch;
        while ((stateMatch = stateRegex.exec(attrs)) !== null) {
          states.push(stateMatch[1]);
        }

        if (states.length > 0) {
          // Remove all state attributes from attrs
          const attrsWithoutStates = attrs.replace(/state="[^"]+"\s*/g, '');
          // Add combined state attribute as comma-separated list
          return `<${tagName} state="${states.join(',')}" ${attrsWithoutStates}>`;
        }
        return match;
      }
    );

    // Preprocess <bygroups> to add _order attribute to preserve element order
    // fast-xml-parser groups elements by type, losing order. We add _order="0", _order="1", etc.
    // to each child element so we can sort them later.
    preprocessed = preprocessed.replace(
      /<bygroups>([\s\S]*?)<\/bygroups>/g,
      (match, content) => {
        let order = 0;
        const ordered = content.replace(/<(usingself|using|token|UsingByGroup)([^>]*)>/g, (m, tagName, attrs) => {
          return `<${tagName} _order="${order++}"${attrs}>`;
        });
        return `<bygroups>${ordered}</bygroups>`;
      }
    );

    return parseLexerXML(preprocessed);
  }

  /**
   * Parse lexer XML content
   * @param {string} xmlContent - XML content as string
   * @returns {Object} Parsed lexer definition
   */
  function parseLexerXML(xmlContent) {
    const parsed = parser.parse(xmlContent);
    const lexer = parsed.lexer;

    if (!lexer) {
      throw new Error('Invalid lexer XML: missing <lexer> root element');
    }

    return transformLexerDef(lexer);
  }

  /**
   * Transform parsed XML into internal lexer definition structure
   * @param {Object} lexer - Parsed lexer XML object
   * @returns {Object} Transformed lexer definition
   */
  function transformLexerDef(lexer) {
    const config = lexer.config || {};
    const rules = lexer.rules || {};
    const states = {};

    // Extract states from rules
    const stateList = Array.isArray(rules.state) ? rules.state : [rules.state];

    for (const state of stateList) {
      if (!state || !state.name) continue;

      states[state.name] = {
        name: state.name,
        rules: parseRules(state.rule || []),
      };
    }

    return {
      name: config.name || '',
      aliases: extractArray(config.alias),
      filenames: extractArray(config.filename),
      mimeTypes: extractArray(config.mime_type),
      ensureNl: config.ensure_nl === 'true' || config.ensure_nl === true,
      caseInsensitive: config.case_insensitive === 'true' || config.case_insensitive === true,
      dotAll: config.dot_all === 'true' || config.dot_all === true,
      states,
    };
  }

  /**
   * Parse rules from a state
   * @param {Array} rules - Array of rule elements from XML
   * @returns {Array} Parsed rules
   */
  function parseRules(rules) {
    const ruleList = Array.isArray(rules) ? rules : [rules];
    const parsed = [];

    for (const rule of ruleList) {
      if (!rule) continue;

      const parsedRule = {
        pattern: rule.pattern || '',
        actions: [],
      };

      // Extract actions
      if (rule.token) {
        parsedRule.actions.push({
          type: 'token',
          tokenType: rule.token.type,
        });
      }

      if ('push' in rule) {
        // push can have multiple states (comma-separated after preprocessing)
        // e.g., <push state="closing-brace,command-body,opening-brace"/>
        const states = rule.push.state ? rule.push.state.split(',') : [];

        parsedRule.actions.push({
          type: 'push',
          state: states.length > 0 ? states[0] : null, // TODO: support pushing multiple states
          states: states, // Store all states for future use
        });
      }

      if ('pop' in rule) {
        parsedRule.actions.push({
          type: 'pop',
          depth: parseInt(rule.pop.depth || '1', 10),
        });
      }

      if ('include' in rule) {
        parsedRule.actions.push({
          type: 'include',
          state: rule.include.state,
        });
      }

      // Handle combined - merges multiple states into one anonymous state
      if ('combined' in rule) {
        // combined can have multiple states, now as comma-separated value
        // e.g., <combined state="stringescape,dqs"/>
        const states = rule.combined.state ? rule.combined.state.split(',') : [];

        parsedRule.actions.push({
          type: 'combined',
          states,
        });
      }

      // Handle using - shunts matched text to another lexer
      if ('using' in rule) {
        parsedRule.actions.push({
          type: 'using',
          lexer: rule.using.lexer,
        });
      }

      // Handle bygroups - creates multiple tokens from capture groups
      if (rule.bygroups) {
        const groups = [];

        // Extract tokens
        const tokens = Array.isArray(rule.bygroups.token) ? rule.bygroups.token : (rule.bygroups.token ? [rule.bygroups.token] : []);

        // Extract usingself elements
        const usingselfs = Array.isArray(rule.bygroups.usingself) ? rule.bygroups.usingself : (rule.bygroups.usingself ? [rule.bygroups.usingself] : []);

        // Extract using elements
        const usings = Array.isArray(rule.bygroups.using) ? rule.bygroups.using : (rule.bygroups.using ? [rule.bygroups.using] : []);

        // Extract UsingByGroup elements
        const usingByGroups = Array.isArray(rule.bygroups.UsingByGroup) ? rule.bygroups.UsingByGroup : (rule.bygroups.UsingByGroup ? [rule.bygroups.UsingByGroup] : []);

        // Use the _order attribute added during preprocessing to preserve original order
        // Collect all groups and sort by _order
        const allGroups = [];

        // Add tokens
        for (const token of tokens) {
          allGroups.push({ ...token, _kind: 'token' });
        }

        // Add usingself elements
        for (const usingself of usingselfs) {
          allGroups.push({ ...usingself, _kind: 'usingself' });
        }

        // Add using elements
        for (const using of usings) {
          allGroups.push({ ...using, _kind: 'using' });
        }

        // Add UsingByGroup elements
        for (const usingByGroup of usingByGroups) {
          allGroups.push({ ...usingByGroup, _kind: 'usingbygroup' });
        }

        // Sort by _order attribute
        allGroups.sort((a, b) => {
          const orderA = parseInt(a._order || 0, 10);
          const orderB = parseInt(b._order || 0, 10);
          return orderA - orderB;
        });

        // Convert sorted elements to group actions
        for (const item of allGroups) {
          if (item._kind === 'token') {
            groups.push({
              type: 'token',
              tokenType: item.type,
            });
          } else if (item._kind === 'usingself') {
            groups.push({
              type: 'usingself',
              state: item.state,
            });
          } else if (item._kind === 'using') {
            groups.push({
              type: 'using',
              lexer: item.lexer,
            });
          } else if (item._kind === 'usingbygroup') {
            groups.push({
              type: 'usingbygroup',
              lexerIndex: parseInt(item.lexer, 10),
              contentIndex: item.content ? item.content.split(',').map(s => parseInt(s.trim(), 10)) : [],
            });
          }
        }

        parsedRule.actions.push({
          type: 'bygroups',
          groups,
        });
      }

      parsed.push(parsedRule);
    }

    return parsed;
  }

  /**
   * Extract array from potentially single value or array
   * @param {any} value - Single value or array
   * @returns {Array} Array of values
   */
  function extractArray(value) {
    if (!value) return [];
    return Array.isArray(value) ? value : [value];
  }

  function r$2(e){if([...e].length!==1)throw new Error(`Expected "${e}" to be a single code point`);return e.codePointAt(0)}function l$1(e,t,n){return e.has(t)||e.set(t,n),e.get(t)}const i=new Set(["alnum","alpha","ascii","blank","cntrl","digit","graph","lower","print","punct","space","upper","word","xdigit"]),o$1=String.raw;function u(e,t){if(e==null)throw new Error(t??"Value expected");return e}

  const m$1=o$1`\[\^?`,b$1=`c.? | C(?:-.?)?|${o$1`[pP]\{(?:\^?[-\x20_]*[A-Za-z][-\x20\w]*\})?`}|${o$1`x[89A-Fa-f]\p{AHex}(?:\\x[89A-Fa-f]\p{AHex})*`}|${o$1`u(?:\p{AHex}{4})? | x\{[^\}]*\}? | x\p{AHex}{0,2}`}|${o$1`o\{[^\}]*\}?`}|${o$1`\d{1,3}`}`,y$1=/[?*+][?+]?|\{(?:\d+(?:,\d*)?|,\d+)\}\??/,C$1=new RegExp(o$1`
  \\ (?:
    ${b$1}
    | [gk]<[^>]*>?
    | [gk]'[^']*'?
    | .
  )
  | \( (?:
    \? (?:
      [:=!>({]
      | <[=!]
      | <[^>]*>
      | '[^']*'
      | ~\|?
      | #(?:[^)\\]|\\.?)*
      | [^:)]*[:)]
    )?
    | \*[^\)]*\)?
  )?
  | (?:${y$1.source})+
  | ${m$1}
  | .
`.replace(/\s+/g,""),"gsu"),T$1=new RegExp(o$1`
  \\ (?:
    ${b$1}
    | .
  )
  | \[:(?:\^?\p{Alpha}+|\^):\]
  | ${m$1}
  | &&
  | .
`.replace(/\s+/g,""),"gsu");function M$1(e,n={}){const t={flags:"",...n,rules:{captureGroup:false,singleline:false,...n.rules}};if(typeof e!="string")throw new Error("String expected as pattern");const o=Y(t.flags),s=[o.extended],a={captureGroup:t.rules.captureGroup,getCurrentModX(){return s.at(-1)},numOpenGroups:0,popModX(){s.pop();},pushModX(u){s.push(u);},replaceCurrentModX(u){s[s.length-1]=u;},singleline:t.rules.singleline};let r=[],i;for(C$1.lastIndex=0;i=C$1.exec(e);){const u=F$1(a,e,i[0],C$1.lastIndex);u.tokens?r.push(...u.tokens):u.token&&r.push(u.token),u.lastIndex!==void 0&&(C$1.lastIndex=u.lastIndex);}const l=[];let c=0;r.filter(u=>u.type==="GroupOpen").forEach(u=>{u.kind==="capturing"?u.number=++c:u.raw==="("&&l.push(u);}),c||l.forEach((u,S)=>{u.kind="capturing",u.number=S+1;});const g=c||l.length;return {tokens:r.map(u=>u.type==="EscapedNumber"?ee$1(u,g):u).flat(),flags:o}}function F$1(e,n,t,o){const[s,a]=t;if(t==="["||t==="[^"){const r=K$1(n,t,o);return {tokens:r.tokens,lastIndex:r.lastIndex}}if(s==="\\"){if("AbBGyYzZ".includes(a))return {token:w$1(t,t)};if(/^\\g[<']/.test(t)){if(!/^\\g(?:<[^>]+>|'[^']+')$/.test(t))throw new Error(`Invalid group name "${t}"`);return {token:R$1(t)}}if(/^\\k[<']/.test(t)){if(!/^\\k(?:<[^>]+>|'[^']+')$/.test(t))throw new Error(`Invalid group name "${t}"`);return {token:A$1(t)}}if(a==="K")return {token:I$1("keep",t)};if(a==="N"||a==="R")return {token:k$1("newline",t,{negate:a==="N"})};if(a==="O")return {token:k$1("any",t)};if(a==="X")return {token:k$1("text_segment",t)};const r=x(t,{inCharClass:false});return Array.isArray(r)?{tokens:r}:{token:r}}if(s==="("){if(a==="*")return {token:j(t)};if(t==="(?{")throw new Error(`Unsupported callout "${t}"`);if(t.startsWith("(?#")){if(n[o]!==")")throw new Error('Unclosed comment group "(?#"');return {lastIndex:o+1}}if(/^\(\?[-imx]+[:)]$/.test(t))return {token:L$1(t,e)};if(e.pushModX(e.getCurrentModX()),e.numOpenGroups++,t==="("&&!e.captureGroup||t==="(?:")return {token:f$1("group",t)};if(t==="(?>")return {token:f$1("atomic",t)};if(t==="(?="||t==="(?!"||t==="(?<="||t==="(?<!")return {token:f$1(t[2]==="<"?"lookbehind":"lookahead",t,{negate:t.endsWith("!")})};if(t==="("&&e.captureGroup||t.startsWith("(?<")&&t.endsWith(">")||t.startsWith("(?'")&&t.endsWith("'"))return {token:f$1("capturing",t,{...t!=="("&&{name:t.slice(3,-1)}})};if(t.startsWith("(?~")){if(t==="(?~|")throw new Error(`Unsupported absence function kind "${t}"`);return {token:f$1("absence_repeater",t)}}throw t==="(?("?new Error(`Unsupported conditional "${t}"`):new Error(`Invalid or unsupported group option "${t}"`)}if(t===")"){if(e.popModX(),e.numOpenGroups--,e.numOpenGroups<0)throw new Error('Unmatched ")"');return {token:Q$1(t)}}if(e.getCurrentModX()){if(t==="#"){const r=n.indexOf(`
`,o);return {lastIndex:r===-1?n.length:r}}if(/^\s$/.test(t)){const r=/\s+/y;return r.lastIndex=o,{lastIndex:r.exec(n)?r.lastIndex:o}}}if(t===".")return {token:k$1("dot",t)};if(t==="^"||t==="$"){const r=e.singleline?{"^":o$1`\A`,$:o$1`\Z`}[t]:t;return {token:w$1(r,t)}}return t==="|"?{token:P$1(t)}:y$1.test(t)?{tokens:te$1(t)}:{token:d(r$2(t),t)}}function K$1(e,n,t){const o=[E$1(n[1]==="^",n)];let s=1,a;for(T$1.lastIndex=t;a=T$1.exec(e);){const r=a[0];if(r[0]==="["&&r[1]!==":")s++,o.push(E$1(r[1]==="^",r));else if(r==="]"){if(o.at(-1).type==="CharacterClassOpen")o.push(d(93,r));else if(s--,o.push(z$1(r)),!s)break}else {const i=X$1(r);Array.isArray(i)?o.push(...i):o.push(i);}}return {tokens:o,lastIndex:T$1.lastIndex||e.length}}function X$1(e){if(e[0]==="\\")return x(e,{inCharClass:true});if(e[0]==="["){const n=/\[:(?<negate>\^?)(?<name>[a-z]+):\]/.exec(e);if(!n||!i.has(n.groups.name))throw new Error(`Invalid POSIX class "${e}"`);return k$1("posix",e,{value:n.groups.name,negate:!!n.groups.negate})}return e==="-"?U$1(e):e==="&&"?H(e):d(r$2(e),e)}function x(e,{inCharClass:n}){const t=e[1];if(t==="c"||t==="C")return Z(e);if("dDhHsSwW".includes(t))return q(e);if(e.startsWith(o$1`\o{`))throw new Error(`Incomplete, invalid, or unsupported octal code point "${e}"`);if(/^\\[pP]\{/.test(e)){if(e.length===3)throw new Error(`Incomplete or invalid Unicode property "${e}"`);return V$1(e)}if(/^\\x[89A-Fa-f]\p{AHex}/u.test(e))try{const o=e.split(/\\x/).slice(1).map(i=>parseInt(i,16)),s=new TextDecoder("utf-8",{ignoreBOM:!0,fatal:!0}).decode(new Uint8Array(o)),a=new TextEncoder;return [...s].map(i=>{const l=[...a.encode(i)].map(c=>`\\x${c.toString(16)}`).join("");return d(r$2(i),l)})}catch{throw new Error(`Multibyte code "${e}" incomplete or invalid in Oniguruma`)}if(t==="u"||t==="x")return d(J$1(e),e);if($$1.has(t))return d($$1.get(t),e);if(/\d/.test(t))return W$1(n,e);if(e==="\\")throw new Error(o$1`Incomplete escape "\"`);if(t==="M")throw new Error(`Unsupported meta "${e}"`);if([...e].length===2)return d(e.codePointAt(1),e);throw new Error(`Unexpected escape "${e}"`)}function P$1(e){return {type:"Alternator",raw:e}}function w$1(e,n){return {type:"Assertion",kind:e,raw:n}}function A$1(e){return {type:"Backreference",raw:e}}function d(e,n){return {type:"Character",value:e,raw:n}}function z$1(e){return {type:"CharacterClassClose",raw:e}}function U$1(e){return {type:"CharacterClassHyphen",raw:e}}function H(e){return {type:"CharacterClassIntersector",raw:e}}function E$1(e,n){return {type:"CharacterClassOpen",negate:e,raw:n}}function k$1(e,n,t={}){return {type:"CharacterSet",kind:e,...t,raw:n}}function I$1(e,n,t={}){return e==="keep"?{type:"Directive",kind:e,raw:n}:{type:"Directive",kind:e,flags:u(t.flags),raw:n}}function W$1(e,n){return {type:"EscapedNumber",inCharClass:e,raw:n}}function Q$1(e){return {type:"GroupClose",raw:e}}function f$1(e,n,t={}){return {type:"GroupOpen",kind:e,...t,raw:n}}function D$1(e,n,t,o){return {type:"NamedCallout",kind:e,tag:n,arguments:t,raw:o}}function _$1(e,n,t,o){return {type:"Quantifier",kind:e,min:n,max:t,raw:o}}function R$1(e){return {type:"Subroutine",raw:e}}const B$1=new Set(["COUNT","CMP","ERROR","FAIL","MAX","MISMATCH","SKIP","TOTAL_COUNT"]),$$1=new Map([["a",7],["b",8],["e",27],["f",12],["n",10],["r",13],["t",9],["v",11]]);function Z(e){const n=e[1]==="c"?e[2]:e[3];if(!n||!/[A-Za-z]/.test(n))throw new Error(`Unsupported control character "${e}"`);return d(r$2(n.toUpperCase())-64,e)}function L$1(e,n){let{on:t,off:o}=/^\(\?(?<on>[imx]*)(?:-(?<off>[-imx]*))?/.exec(e).groups;o??="";const s=(n.getCurrentModX()||t.includes("x"))&&!o.includes("x"),a=v(t),r=v(o),i={};if(a&&(i.enable=a),r&&(i.disable=r),e.endsWith(")"))return n.replaceCurrentModX(s),I$1("flags",e,{flags:i});if(e.endsWith(":"))return n.pushModX(s),n.numOpenGroups++,f$1("group",e,{...(a||r)&&{flags:i}});throw new Error(`Unexpected flag modifier "${e}"`)}function j(e){const n=/\(\*(?<name>[A-Za-z_]\w*)?(?:\[(?<tag>(?:[A-Za-z_]\w*)?)\])?(?:\{(?<args>[^}]*)\})?\)/.exec(e);if(!n)throw new Error(`Incomplete or invalid named callout "${e}"`);const{name:t,tag:o,args:s}=n.groups;if(!t)throw new Error(`Invalid named callout "${e}"`);if(o==="")throw new Error(`Named callout tag with empty value not allowed "${e}"`);const a=s?s.split(",").filter(g=>g!=="").map(g=>/^[+-]?\d+$/.test(g)?+g:g):[],[r,i,l]=a,c=B$1.has(t)?t.toLowerCase():"custom";switch(c){case "fail":case "mismatch":case "skip":if(a.length>0)throw new Error(`Named callout arguments not allowed "${a}"`);break;case "error":if(a.length>1)throw new Error(`Named callout allows only one argument "${a}"`);if(typeof r=="string")throw new Error(`Named callout argument must be a number "${r}"`);break;case "max":if(!a.length||a.length>2)throw new Error(`Named callout must have one or two arguments "${a}"`);if(typeof r=="string"&&!/^[A-Za-z_]\w*$/.test(r))throw new Error(`Named callout argument one must be a tag or number "${r}"`);if(a.length===2&&(typeof i=="number"||!/^[<>X]$/.test(i)))throw new Error(`Named callout optional argument two must be '<', '>', or 'X' "${i}"`);break;case "count":case "total_count":if(a.length>1)throw new Error(`Named callout allows only one argument "${a}"`);if(a.length===1&&(typeof r=="number"||!/^[<>X]$/.test(r)))throw new Error(`Named callout optional argument must be '<', '>', or 'X' "${r}"`);break;case "cmp":if(a.length!==3)throw new Error(`Named callout must have three arguments "${a}"`);if(typeof r=="string"&&!/^[A-Za-z_]\w*$/.test(r))throw new Error(`Named callout argument one must be a tag or number "${r}"`);if(typeof i=="number"||!/^(?:[<>!=]=|[<>])$/.test(i))throw new Error(`Named callout argument two must be '==', '!=', '>', '<', '>=', or '<=' "${i}"`);if(typeof l=="string"&&!/^[A-Za-z_]\w*$/.test(l))throw new Error(`Named callout argument three must be a tag or number "${l}"`);break;case "custom":throw new Error(`Undefined callout name "${t}"`);default:throw new Error(`Unexpected named callout kind "${c}"`)}return D$1(c,o??null,s?.split(",")??null,e)}function O$1(e){let n=null,t,o;if(e[0]==="{"){const{minStr:s,maxStr:a}=/^\{(?<minStr>\d*)(?:,(?<maxStr>\d*))?/.exec(e).groups,r=1e5;if(+s>r||a&&+a>r)throw new Error("Quantifier value unsupported in Oniguruma");if(t=+s,o=a===void 0?+s:a===""?1/0:+a,t>o&&(n="possessive",[t,o]=[o,t]),e.endsWith("?")){if(n==="possessive")throw new Error('Unsupported possessive interval quantifier chain with "?"');n="lazy";}else n||(n="greedy");}else t=e[0]==="+"?1:0,o=e[0]==="?"?1:1/0,n=e[1]==="+"?"possessive":e[1]==="?"?"lazy":"greedy";return _$1(n,t,o,e)}function q(e){const n=e[1].toLowerCase();return k$1({d:"digit",h:"hex",s:"space",w:"word"}[n],e,{negate:e[1]!==n})}function V$1(e){const{p:n,neg:t,value:o}=/^\\(?<p>[pP])\{(?<neg>\^?)(?<value>[^}]+)/.exec(e).groups;return k$1("property",e,{value:o,negate:n==="P"&&!t||n==="p"&&!!t})}function v(e){const n={};return e.includes("i")&&(n.ignoreCase=true),e.includes("m")&&(n.dotAll=true),e.includes("x")&&(n.extended=true),Object.keys(n).length?n:null}function Y(e){const n={ignoreCase:false,dotAll:false,extended:false,digitIsAscii:false,posixIsAscii:false,spaceIsAscii:false,wordIsAscii:false,textSegmentMode:null};for(let t=0;t<e.length;t++){const o=e[t];if(!"imxDPSWy".includes(o))throw new Error(`Invalid flag "${o}"`);if(o==="y"){if(!/^y{[gw]}/.test(e.slice(t)))throw new Error('Invalid or unspecified flag "y" mode');n.textSegmentMode=e[t+2]==="g"?"grapheme":"word",t+=3;continue}n[{i:"ignoreCase",m:"dotAll",x:"extended",D:"digitIsAscii",P:"posixIsAscii",S:"spaceIsAscii",W:"wordIsAscii"}[o]]=true;}return n}function J$1(e){if(/^(?:\\u(?!\p{AHex}{4})|\\x(?!\p{AHex}{1,2}|\{\p{AHex}{1,8}\}))/u.test(e))throw new Error(`Incomplete or invalid escape "${e}"`);const n=e[2]==="{"?/^\\x\{\s*(?<hex>\p{AHex}+)/u.exec(e).groups.hex:e.slice(2);return parseInt(n,16)}function ee$1(e,n){const{raw:t,inCharClass:o}=e,s=t.slice(1);if(!o&&(s!=="0"&&s.length===1||s[0]!=="0"&&+s<=n))return [A$1(t)];const a=[],r=s.match(/^[0-7]+|\d/g);for(let i=0;i<r.length;i++){const l=r[i];let c;if(i===0&&l!=="8"&&l!=="9"){if(c=parseInt(l,8),c>127)throw new Error(o$1`Octal encoded byte above 177 unsupported "${t}"`)}else c=r$2(l);a.push(d(c,(i===0?"\\":"")+l));}return a}function te$1(e){const n=[],t=new RegExp(y$1,"gy");let o;for(;o=t.exec(e);){const s=o[0];if(s[0]==="{"){const a=/^\{(?<min>\d+),(?<max>\d+)\}\??$/.exec(s);if(a){const{min:r,max:i}=a.groups;if(+r>+i&&s.endsWith("?")){t.lastIndex--,n.push(O$1(s.slice(0,-1)));continue}}}n.push(O$1(s));}return n}

  function o(e,t){if(!Array.isArray(e.body))throw new Error("Expected node with body array");if(e.body.length!==1)return  false;const r=e.body[0];return !t||Object.keys(t).every(n=>t[n]===r[n])}function s(e){return y.has(e.type)}const y=new Set(["AbsenceFunction","Backreference","CapturingGroup","Character","CharacterClass","CharacterSet","Group","Quantifier","Subroutine"]);

  function J(e,r={}){const n={flags:"",normalizeUnknownPropertyNames:false,skipBackrefValidation:false,skipLookbehindValidation:false,skipPropertyNameValidation:false,unicodePropertyMap:null,...r,rules:{captureGroup:false,singleline:false,...r.rules}},t=M$1(e,{flags:n.flags,rules:{captureGroup:n.rules.captureGroup,singleline:n.rules.singleline}}),s=(p,N)=>{const u=t.tokens[o.nextIndex];switch(o.parent=p,o.nextIndex++,u.type){case "Alternator":return b();case "Assertion":return W(u);case "Backreference":return X(u,o);case "Character":return m(u.value,{useLastValid:!!N.isCheckingRangeEnd});case "CharacterClassHyphen":return ee(u,o,N);case "CharacterClassOpen":return re(u,o,N);case "CharacterSet":return ne(u,o);case "Directive":return I(u.kind,{flags:u.flags});case "GroupOpen":return te(u,o,N);case "NamedCallout":return U(u.kind,u.tag,u.arguments);case "Quantifier":return oe(u,o);case "Subroutine":return ae(u,o);default:throw new Error(`Unexpected token type "${u.type}"`)}},o={capturingGroups:[],hasNumberedRef:false,namedGroupsByName:new Map,nextIndex:0,normalizeUnknownPropertyNames:n.normalizeUnknownPropertyNames,parent:null,skipBackrefValidation:n.skipBackrefValidation,skipLookbehindValidation:n.skipLookbehindValidation,skipPropertyNameValidation:n.skipPropertyNameValidation,subroutines:[],tokens:t.tokens,unicodePropertyMap:n.unicodePropertyMap,walk:s},i=B(T(t.flags));let d=i.body[0];for(;o.nextIndex<t.tokens.length;){const p=s(d,{});p.type==="Alternative"?(i.body.push(p),d=p):d.body.push(p);}const{capturingGroups:a,hasNumberedRef:l,namedGroupsByName:c,subroutines:f}=o;if(l&&c.size&&!n.rules.captureGroup)throw new Error("Numbered backref/subroutine not allowed when using named capture");for(const{ref:p}of f)if(typeof p=="number"){if(p>a.length)throw new Error("Subroutine uses a group number that's not defined");p&&(a[p-1].isSubroutined=true);}else if(c.has(p)){if(c.get(p).length>1)throw new Error(o$1`Subroutine uses a duplicate group name "\g<${p}>"`);c.get(p)[0].isSubroutined=true;}else throw new Error(o$1`Subroutine uses a group name that's not defined "\g<${p}>"`);return i}function W({kind:e}){return F(u({"^":"line_start",$:"line_end","\\A":"string_start","\\b":"word_boundary","\\B":"word_boundary","\\G":"search_start","\\y":"text_segment_boundary","\\Y":"text_segment_boundary","\\z":"string_end","\\Z":"string_end_newline"}[e],`Unexpected assertion kind "${e}"`),{negate:e===o$1`\B`||e===o$1`\Y`})}function X({raw:e},r){const n=/^\\k[<']/.test(e),t=n?e.slice(3,-1):e.slice(1),s=(o,i=false)=>{const d=r.capturingGroups.length;let a=false;if(o>d)if(r.skipBackrefValidation)a=true;else throw new Error(`Not enough capturing groups defined to the left "${e}"`);return r.hasNumberedRef=true,k(i?d+1-o:o,{orphan:a})};if(n){const o=/^(?<sign>-?)0*(?<num>[1-9]\d*)$/.exec(t);if(o)return s(+o.groups.num,!!o.groups.sign);if(/[-+]/.test(t))throw new Error(`Invalid backref name "${e}"`);if(!r.namedGroupsByName.has(t))throw new Error(`Group name not defined to the left "${e}"`);return k(t)}return s(+t)}function ee(e,r,n){const{tokens:t,walk:s}=r,o=r.parent,i=o.body.at(-1),d=t[r.nextIndex];if(!n.isCheckingRangeEnd&&i&&i.type!=="CharacterClass"&&i.type!=="CharacterClassRange"&&d&&d.type!=="CharacterClassOpen"&&d.type!=="CharacterClassClose"&&d.type!=="CharacterClassIntersector"){const a=s(o,{...n,isCheckingRangeEnd:true});if(i.type==="Character"&&a.type==="Character")return o.body.pop(),L(i,a);throw new Error("Invalid character class range")}return m(r$2("-"))}function re({negate:e},r,n){const{tokens:t,walk:s}=r,o=t[r.nextIndex],i=[C()];let d=z(o);for(;d.type!=="CharacterClassClose";){if(d.type==="CharacterClassIntersector")i.push(C()),r.nextIndex++;else {const l=i.at(-1);l.body.push(s(l,n));}d=z(t[r.nextIndex],o);}const a=C({negate:e});return i.length===1?a.body=i[0].body:(a.kind="intersection",a.body=i.map(l=>l.body.length===1?l.body[0]:l)),r.nextIndex++,a}function ne({kind:e,negate:r,value:n},t){const{normalizeUnknownPropertyNames:s,skipPropertyNameValidation:o,unicodePropertyMap:i$1}=t;if(e==="property"){const d=w(n);if(i.has(d)&&!i$1?.has(d))e="posix",n=d;else return Q(n,{negate:r,normalizeUnknownPropertyNames:s,skipPropertyNameValidation:o,unicodePropertyMap:i$1})}return e==="posix"?R(n,{negate:r}):E(e,{negate:r})}function te(e,r,n){const{tokens:t,capturingGroups:s,namedGroupsByName:o,skipLookbehindValidation:i,walk:d}=r,a=ie(e),l=a.type==="AbsenceFunction",c=$(a),f=c&&a.negate;if(a.type==="CapturingGroup"&&(s.push(a),a.name&&l$1(o,a.name,[]).push(a)),l&&n.isInAbsenceFunction)throw new Error("Nested absence function not supported by Oniguruma");let p=D(t[r.nextIndex]);for(;p.type!=="GroupClose";){if(p.type==="Alternator")a.body.push(b()),r.nextIndex++;else {const N=a.body.at(-1),u=d(N,{...n,isInAbsenceFunction:n.isInAbsenceFunction||l,isInLookbehind:n.isInLookbehind||c,isInNegLookbehind:n.isInNegLookbehind||f});if(N.body.push(u),(c||n.isInLookbehind)&&!i){const v="Lookbehind includes a pattern not allowed by Oniguruma";if(f||n.isInNegLookbehind){if(M(u)||u.type==="CapturingGroup")throw new Error(v)}else if(M(u)||$(u)&&u.negate)throw new Error(v)}}p=D(t[r.nextIndex]);}return r.nextIndex++,a}function oe({kind:e,min:r,max:n},t){const s$1=t.parent,o=s$1.body.at(-1);if(!o||!s(o))throw new Error("Quantifier requires a repeatable token");const i=_(e,r,n,o);return s$1.body.pop(),i}function ae({raw:e},r){const{capturingGroups:n,subroutines:t}=r;let s=e.slice(3,-1);const o=/^(?<sign>[-+]?)0*(?<num>[1-9]\d*)$/.exec(s);if(o){const d=+o.groups.num,a=n.length;if(r.hasNumberedRef=true,s={"":d,"+":a+d,"-":a+1-d}[o.groups.sign],s<1)throw new Error("Invalid subroutine number")}else s==="0"&&(s=0);const i=O(s);return t.push(i),i}function G(e,r){return {type:"AbsenceFunction",kind:e,body:h(r?.body)}}function b(e){return {type:"Alternative",body:V(e?.body)}}function F(e,r){const n={type:"Assertion",kind:e};return (e==="word_boundary"||e==="text_segment_boundary")&&(n.negate=!!r?.negate),n}function k(e,r){const n=!!r?.orphan;return {type:"Backreference",ref:e,...n&&{orphan:n}}}function P(e,r){const n={name:void 0,isSubroutined:false,...r};if(n.name!==void 0&&!se(n.name))throw new Error(`Group name "${n.name}" invalid in Oniguruma`);return {type:"CapturingGroup",number:e,...n.name&&{name:n.name},...n.isSubroutined&&{isSubroutined:n.isSubroutined},body:h(r?.body)}}function m(e,r){const n={useLastValid:false,...r};if(e>1114111){const t=e.toString(16);if(n.useLastValid)e=1114111;else throw e>1310719?new Error(`Invalid code point out of range "\\x{${t}}"`):new Error(`Invalid code point out of range in JS "\\x{${t}}"`)}return {type:"Character",value:e}}function C(e){const r={kind:"union",negate:false,...e};return {type:"CharacterClass",kind:r.kind,negate:r.negate,body:V(e?.body)}}function L(e,r){if(r.value<e.value)throw new Error("Character class range out of order");return {type:"CharacterClassRange",min:e,max:r}}function E(e,r){const n=!!r?.negate,t={type:"CharacterSet",kind:e};return (e==="digit"||e==="hex"||e==="newline"||e==="space"||e==="word")&&(t.negate=n),(e==="text_segment"||e==="newline"&&!n)&&(t.variableLength=true),t}function I(e,r={}){if(e==="keep")return {type:"Directive",kind:e};if(e==="flags")return {type:"Directive",kind:e,flags:u(r.flags)};throw new Error(`Unexpected directive kind "${e}"`)}function T(e){return {type:"Flags",...e}}function A(e){const r=e?.atomic,n=e?.flags;if(r&&n)throw new Error("Atomic group cannot have flags");return {type:"Group",...r&&{atomic:r},...n&&{flags:n},body:h(e?.body)}}function K(e){const r={behind:false,negate:false,...e};return {type:"LookaroundAssertion",kind:r.behind?"lookbehind":"lookahead",negate:r.negate,body:h(e?.body)}}function U(e,r,n){return {type:"NamedCallout",kind:e,tag:r,arguments:n}}function R(e,r){const n=!!r?.negate;if(!i.has(e))throw new Error(`Invalid POSIX class "${e}"`);return {type:"CharacterSet",kind:"posix",value:e,negate:n}}function _(e,r,n,t){if(r>n)throw new Error("Invalid reversed quantifier range");return {type:"Quantifier",kind:e,min:r,max:n,body:t}}function B(e,r){return {type:"Regex",body:h(r?.body),flags:e}}function O(e){return {type:"Subroutine",ref:e}}function Q(e,r){const n={negate:false,normalizeUnknownPropertyNames:false,skipPropertyNameValidation:false,unicodePropertyMap:null,...r};let t=n.unicodePropertyMap?.get(w(e));if(!t){if(n.normalizeUnknownPropertyNames)t=de(e);else if(n.unicodePropertyMap&&!n.skipPropertyNameValidation)throw new Error(o$1`Invalid Unicode property "\p{${e}}"`)}return {type:"CharacterSet",kind:"property",value:t??e,negate:n.negate}}function ie({flags:e,kind:r,name:n,negate:t,number:s}){switch(r){case "absence_repeater":return G("repeater");case "atomic":return A({atomic:true});case "capturing":return P(s,{name:n});case "group":return A({flags:e});case "lookahead":case "lookbehind":return K({behind:r==="lookbehind",negate:t});default:throw new Error(`Unexpected group kind "${r}"`)}}function h(e){if(e===void 0)e=[b()];else if(!Array.isArray(e)||!e.length||!e.every(r=>r.type==="Alternative"))throw new Error("Invalid body; expected array of one or more Alternative nodes");return e}function V(e){if(e===void 0)e=[];else if(!Array.isArray(e)||!e.every(r=>!!r.type))throw new Error("Invalid body; expected array of nodes");return e}function M(e){return e.type==="LookaroundAssertion"&&e.kind==="lookahead"}function $(e){return e.type==="LookaroundAssertion"&&e.kind==="lookbehind"}function se(e){return /^[\p{Alpha}\p{Pc}][^)]*$/u.test(e)}function de(e){return e.trim().replace(/[- _]+/g,"_").replace(/[A-Z][a-z]+(?=[A-Z])/g,"$&_").replace(/[A-Za-z]+/g,r=>r[0].toUpperCase()+r.slice(1).toLowerCase())}function w(e){return e.replace(/[- _]+/g,"").toLowerCase()}function z(e,r){return u(e,`${r?.type==="Character"&&r.value===93?"Empty":"Unclosed"} character class`)}function D(e){return u(e,"Unclosed group")}

  function S(a,v,N=null){function u$1(e,s){for(let t=0;t<e.length;t++){const r=n(e[t],s,t,e);t=Math.max(-1,t+r);}}function n(e,s=null,t=null,r=null){let i=0,c=false;const d={node:e,parent:s,key:t,container:r,root:a,remove(){f(r).splice(Math.max(0,l(t)+i),1),i--,c=true;},removeAllNextSiblings(){return f(r).splice(l(t)+1)},removeAllPrevSiblings(){const o=l(t)+i;return i-=o,f(r).splice(0,Math.max(0,o))},replaceWith(o,y={}){const b=!!y.traverse;r?r[Math.max(0,l(t)+i)]=o:u(s,"Can't replace root node")[t]=o,b&&n(o,s,t,r),c=true;},replaceWithMultiple(o,y={}){const b=!!y.traverse;if(f(r).splice(Math.max(0,l(t)+i),1,...o),i+=o.length-1,b){let g=0;for(let x=0;x<o.length;x++)g+=n(o[x],s,l(t)+x+g,r);}c=true;},skip(){c=true;}},{type:m}=e,h=v["*"],p=v[m],R=typeof h=="function"?h:h?.enter,P=typeof p=="function"?p:p?.enter;if(R?.(d,N),P?.(d,N),!c)switch(m){case "AbsenceFunction":case "CapturingGroup":case "Group":u$1(e.body,e);break;case "Alternative":case "CharacterClass":u$1(e.body,e);break;case "Assertion":case "Backreference":case "Character":case "CharacterSet":case "Directive":case "Flags":case "NamedCallout":case "Subroutine":break;case "CharacterClassRange":n(e.min,e,"min"),n(e.max,e,"max");break;case "LookaroundAssertion":u$1(e.body,e);break;case "Quantifier":n(e.body,e,"body");break;case "Regex":u$1(e.body,e),n(e.flags,e,"flags");break;default:throw new Error(`Unexpected node type "${m}"`)}return p?.exit?.(d,N),h?.exit?.(d,N),i}return n(a),a}function f(a){if(!Array.isArray(a))throw new Error("Container expected");return a}function l(a){if(typeof a!="number")throw new Error("Numeric key expected");return a}

  // Separating some utils for improved tree shaking of the `./internals` export

  const noncapturingDelim = String.raw`\(\?(?:[:=!>A-Za-z\-]|<[=!]|\(DEFINE\))`;

  /**
  Updates the array in place by incrementing each value greater than or equal to the threshold.
  @param {Array<number>} arr
  @param {number} threshold
  */
  function incrementIfAtLeast$1(arr, threshold) {
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] >= threshold) {
        arr[i]++;
      }
    }
  }

  /**
  @param {string} str
  @param {number} pos
  @param {string} oldValue
  @param {string} newValue
  @returns {string}
  */
  function spliceStr(str, pos, oldValue, newValue) {
    return str.slice(0, pos) + newValue + str.slice(pos + oldValue.length);
  }

  // Constant properties for tracking regex syntax context
  const Context = Object.freeze({
    DEFAULT: 'DEFAULT',
    CHAR_CLASS: 'CHAR_CLASS',
  });

  /**
  Replaces all unescaped instances of a regex pattern in the given context, using a replacement
  string or callback.

  Doesn't skip over complete multicharacter tokens (only `\` plus its folowing char) so must be used
  with knowledge of what's safe to do given regex syntax. Assumes UnicodeSets-mode syntax.
  @param {string} expression Search target
  @param {string} needle Search as a regex pattern, with flags `su` applied
  @param {string | (match: RegExpExecArray, details: {
    context: 'DEFAULT' | 'CHAR_CLASS';
    negated: boolean;
  }) => string} replacement
  @param {'DEFAULT' | 'CHAR_CLASS'} [context] All contexts if not specified
  @returns {string} Updated expression
  @example
  const str = '.\\.\\\\.[[\\.].].';
  replaceUnescaped(str, '\\.', '@');
  // → '@\\.\\\\@[[\\.]@]@'
  replaceUnescaped(str, '\\.', '@', Context.DEFAULT);
  // → '@\\.\\\\@[[\\.].]@'
  replaceUnescaped(str, '\\.', '@', Context.CHAR_CLASS);
  // → '.\\.\\\\.[[\\.]@].'
  */
  function replaceUnescaped(expression, needle, replacement, context) {
    const re = new RegExp(String.raw`${needle}|(?<$skip>\[\^?|\\?.)`, 'gsu');
    const negated = [false];
    let numCharClassesOpen = 0;
    let result = '';
    for (const match of expression.matchAll(re)) {
      const {0: m, groups: {$skip}} = match;
      if (!$skip && (!context || (context === Context.DEFAULT) === !numCharClassesOpen)) {
        if (replacement instanceof Function) {
          result += replacement(match, {
            context: numCharClassesOpen ? Context.CHAR_CLASS : Context.DEFAULT,
            negated: negated[negated.length - 1],
          });
        } else {
          result += replacement;
        }
        continue;
      }
      if (m[0] === '[') {
        numCharClassesOpen++;
        negated.push(m[1] === '^');
      } else if (m === ']' && numCharClassesOpen) {
        numCharClassesOpen--;
        negated.pop();
      }
      result += m;
    }
    return result;
  }

  /**
  Runs a callback for each unescaped instance of a regex pattern in the given context.

  Doesn't skip over complete multicharacter tokens (only `\` plus its folowing char) so must be used
  with knowledge of what's safe to do given regex syntax. Assumes UnicodeSets-mode syntax.
  @param {string} expression Search target
  @param {string} needle Search as a regex pattern, with flags `su` applied
  @param {(match: RegExpExecArray, details: {
    context: 'DEFAULT' | 'CHAR_CLASS';
    negated: boolean;
  }) => void} callback
  @param {'DEFAULT' | 'CHAR_CLASS'} [context] All contexts if not specified
  */
  function forEachUnescaped(expression, needle, callback, context) {
    // Do this the easy way
    replaceUnescaped(expression, needle, callback, context);
  }

  /**
  Returns a match object for the first unescaped instance of a regex pattern in the given context, or
  `null`.

  Doesn't skip over complete multicharacter tokens (only `\` plus its folowing char) so must be used
  with knowledge of what's safe to do given regex syntax. Assumes UnicodeSets-mode syntax.
  @param {string} expression Search target
  @param {string} needle Search as a regex pattern, with flags `su` applied
  @param {number} [pos] Offset to start the search
  @param {'DEFAULT' | 'CHAR_CLASS'} [context] All contexts if not specified
  @returns {RegExpExecArray | null}
  */
  function execUnescaped(expression, needle, pos = 0, context) {
    // Quick partial test; avoid the loop if not needed
    if (!(new RegExp(needle, 'su').test(expression))) {
      return null;
    }
    const re = new RegExp(`${needle}|(?<$skip>\\\\?.)`, 'gsu');
    re.lastIndex = pos;
    let numCharClassesOpen = 0;
    let match;
    while (match = re.exec(expression)) {
      const {0: m, groups: {$skip}} = match;
      if (!$skip && (!context || (context === Context.DEFAULT) === !numCharClassesOpen)) {
        return match;
      }
      if (m === '[') {
        numCharClassesOpen++;
      } else if (m === ']' && numCharClassesOpen) {
        numCharClassesOpen--;
      }
      // Avoid an infinite loop on zero-length matches
      if (re.lastIndex == match.index) {
        re.lastIndex++;
      }
    }
    return null;
  }

  /**
  Checks whether an unescaped instance of a regex pattern appears in the given context.

  Doesn't skip over complete multicharacter tokens (only `\` plus its folowing char) so must be used
  with knowledge of what's safe to do given regex syntax. Assumes UnicodeSets-mode syntax.
  @param {string} expression Search target
  @param {string} needle Search as a regex pattern, with flags `su` applied
  @param {'DEFAULT' | 'CHAR_CLASS'} [context] All contexts if not specified
  @returns {boolean} Whether the pattern was found
  */
  function hasUnescaped(expression, needle, context) {
    // Do this the easy way
    return !!execUnescaped(expression, needle, 0, context);
  }

  /**
  Extracts the full contents of a group (subpattern) from the given expression, accounting for
  escaped characters, nested groups, and character classes. The group is identified by the position
  where its contents start (the string index just after the group's opening delimiter). Returns the
  rest of the string if the group is unclosed.

  Assumes UnicodeSets-mode syntax.
  @param {string} expression Search target
  @param {number} contentsStartPos
  @returns {string}
  */
  function getGroupContents(expression, contentsStartPos) {
    const token = /\\?./gsu;
    token.lastIndex = contentsStartPos;
    let contentsEndPos = expression.length;
    let numCharClassesOpen = 0;
    // Starting search within an open group, after the group's opening
    let numGroupsOpen = 1;
    let match;
    while (match = token.exec(expression)) {
      const [m] = match;
      if (m === '[') {
        numCharClassesOpen++;
      } else if (!numCharClassesOpen) {
        if (m === '(') {
          numGroupsOpen++;
        } else if (m === ')') {
          numGroupsOpen--;
          if (!numGroupsOpen) {
            contentsEndPos = match.index;
            break;
          }
        }
      } else if (m === ']') {
        numCharClassesOpen--;
      }
    }
    return expression.slice(contentsStartPos, contentsEndPos);
  }

  /**
  @import {PluginData, PluginResult} from './regex.js';
  */

  const atomicPluginToken = new RegExp(String.raw`(?<noncapturingStart>${noncapturingDelim})|(?<capturingStart>\((?:\?<[^>]+>)?)|\\?.`, 'gsu');

  /**
  Apply transformations for atomic groups: `(?>…)`.
  @param {string} expression
  @param {PluginData} [data]
  @returns {Required<PluginResult>}
  */
  function atomic(expression, data) {
    const hiddenCaptures = data?.hiddenCaptures ?? [];
    // Capture transfer is used by <github.com/slevithan/oniguruma-to-es>
    let captureTransfers = data?.captureTransfers ?? new Map();
    if (!/\(\?>/.test(expression)) {
      return {
        pattern: expression,
        captureTransfers,
        hiddenCaptures,
      };
    }

    const aGDelim = '(?>';
    const emulatedAGDelim = '(?:(?=(';
    const captureNumMap = [0];
    const addedHiddenCaptures = [];
    let numCapturesBeforeAG = 0;
    let numAGs = 0;
    let aGPos = NaN;
    let hasProcessedAG;
    do {
      hasProcessedAG = false;
      let numCharClassesOpen = 0;
      let numGroupsOpenInAG = 0;
      let inAG = false;
      let match;
      atomicPluginToken.lastIndex = Number.isNaN(aGPos) ? 0 : aGPos + emulatedAGDelim.length;
      while (match = atomicPluginToken.exec(expression)) {
        const {0: m, index, groups: {capturingStart, noncapturingStart}} = match;
        if (m === '[') {
          numCharClassesOpen++;
        } else if (!numCharClassesOpen) {

          if (m === aGDelim && !inAG) {
            aGPos = index;
            inAG = true;
          } else if (inAG && noncapturingStart) {
            numGroupsOpenInAG++;
          } else if (capturingStart) {
            if (inAG) {
              numGroupsOpenInAG++;
            } else {
              numCapturesBeforeAG++;
              captureNumMap.push(numCapturesBeforeAG + numAGs);
            }
          } else if (m === ')' && inAG) {
            if (!numGroupsOpenInAG) {
              numAGs++;
              const addedCaptureNum = numCapturesBeforeAG + numAGs;
              // Replace `expression` and use `<$$N>` as a temporary wrapper for the backref so it
              // can avoid backref renumbering afterward. Wrap the whole substitution (including the
              // lookahead and following backref) in a noncapturing group to handle following
              // quantifiers and literal digits
              expression = `${expression.slice(0, aGPos)}${emulatedAGDelim}${
                expression.slice(aGPos + aGDelim.length, index)
              }))<$$${addedCaptureNum}>)${expression.slice(index + 1)}`;
              hasProcessedAG = true;
              addedHiddenCaptures.push(addedCaptureNum);
              incrementIfAtLeast$1(hiddenCaptures, addedCaptureNum);
              if (captureTransfers.size) {
                const newCaptureTransfers = new Map();
                captureTransfers.forEach((from, to) => {
                  newCaptureTransfers.set(
                    to >= addedCaptureNum ? to + 1 : to,
                    from.map(f => f >= addedCaptureNum ? f + 1 : f)
                  );
                });
                captureTransfers = newCaptureTransfers;
              }
              break;
            }
            numGroupsOpenInAG--;
          }

        } else if (m === ']') {
          numCharClassesOpen--;
        }
      }
    // Start over from the beginning of the atomic group's contents, in case the processed group
    // contains additional atomic groups
    } while (hasProcessedAG);

    hiddenCaptures.push(...addedHiddenCaptures);

    // Second pass to adjust numbered backrefs
    expression = replaceUnescaped(
      expression,
      String.raw`\\(?<backrefNum>[1-9]\d*)|<\$\$(?<wrappedBackrefNum>\d+)>`,
      ({0: m, groups: {backrefNum, wrappedBackrefNum}}) => {
        if (backrefNum) {
          const bNum = +backrefNum;
          if (bNum > captureNumMap.length - 1) {
            throw new Error(`Backref "${m}" greater than number of captures`);
          }
          return `\\${captureNumMap[bNum]}`;
        }
        return `\\${wrappedBackrefNum}`;
      },
      Context.DEFAULT
    );

    return {
      pattern: expression,
      captureTransfers,
      hiddenCaptures,
    };
  }

  const baseQuantifier = String.raw`(?:[?*+]|\{\d+(?:,\d*)?\})`;
  // Complete tokenizer for base syntax; doesn't (need to) know about character-class-only syntax
  const possessivePluginToken = new RegExp(String.raw`
\\(?: \d+
  | c[A-Za-z]
  | [gk]<[^>]+>
  | [pPu]\{[^\}]+\}
  | u[A-Fa-f\d]{4}
  | x[A-Fa-f\d]{2}
  )
| \((?: \? (?: [:=!>]
  | <(?:[=!]|[^>]+>)
  | [A-Za-z\-]+:
  | \(DEFINE\)
  ))?
| (?<qBase>${baseQuantifier})(?<qMod>[?+]?)(?<invalidQ>[?*+\{]?)
| \\?.
`.replace(/\s+/g, ''), 'gsu');

  /**
  Transform posessive quantifiers into atomic groups. The posessessive quantifiers are:
  `?+`, `*+`, `++`, `{N}+`, `{N,}+`, `{N,N}+`.
  This follows Java, PCRE, Perl, and Python.
  Possessive quantifiers in Oniguruma and Onigmo are only: `?+`, `*+`, `++`.
  @param {string} expression
  @returns {PluginResult}
  */
  function possessive(expression) {
    if (!(new RegExp(`${baseQuantifier}\\+`).test(expression))) {
      return {
        pattern: expression,
      };
    }

    const openGroupIndices = [];
    let lastGroupIndex = null;
    let lastCharClassIndex = null;
    let lastToken = '';
    let numCharClassesOpen = 0;
    let match;
    possessivePluginToken.lastIndex = 0;
    while (match = possessivePluginToken.exec(expression)) {
      const {0: m, index, groups: {qBase, qMod, invalidQ}} = match;
      if (m === '[') {
        if (!numCharClassesOpen) {
          lastCharClassIndex = index;
        }
        numCharClassesOpen++;
      } else if (m === ']') {
        if (numCharClassesOpen) {
          numCharClassesOpen--;
        // Unmatched `]`
        } else {
          lastCharClassIndex = null;
        }
      } else if (!numCharClassesOpen) {

        if (qMod === '+' && lastToken && !lastToken.startsWith('(')) {
          // Invalid following quantifier would become valid via the wrapping group
          if (invalidQ) {
            throw new Error(`Invalid quantifier "${m}"`);
          }
          let charsAdded = -1; // -1 for removed trailing `+`
          // Possessivizing fixed repetition quantifiers like `{2}` does't change their behavior, so
          // avoid doing so (convert them to greedy)
          if (/^\{\d+\}$/.test(qBase)) {
            expression = spliceStr(expression, index + qBase.length, qMod, '');
          } else {
            if (lastToken === ')' || lastToken === ']') {
              const nodeIndex = lastToken === ')' ? lastGroupIndex : lastCharClassIndex;
              // Unmatched `)` would break out of the wrapping group and mess with handling.
              // Unmatched `]` wouldn't be a problem, but it's unnecessary to have dedicated support
              // for unescaped `]++` since this won't work with flag u or v anyway
              if (nodeIndex === null) {
                throw new Error(`Invalid unmatched "${lastToken}"`);
              }
              expression = `${expression.slice(0, nodeIndex)}(?>${expression.slice(nodeIndex, index)}${qBase})${expression.slice(index + m.length)}`;
            } else {
              expression = `${expression.slice(0, index - lastToken.length)}(?>${lastToken}${qBase})${expression.slice(index + m.length)}`;
            }
            charsAdded += 4; // `(?>)`
          }
          possessivePluginToken.lastIndex += charsAdded;
        } else if (m[0] === '(') {
          openGroupIndices.push(index);
        } else if (m === ')') {
          lastGroupIndex = openGroupIndices.length ? openGroupIndices.pop() : null;
        }

      }
      lastToken = m;
    }

    return {
      pattern: expression,
    };
  }

  const r$1 = String.raw;
  const gRToken = r$1`\\g<(?<gRNameOrNum>[^>&]+)&R=(?<gRDepth>[^>]+)>`;
  const recursiveToken = r$1`\(\?R=(?<rDepth>[^\)]+)\)|${gRToken}`;
  const namedCaptureDelim = r$1`\(\?<(?![=!])(?<captureName>[^>]+)>`;
  const captureDelim = r$1`${namedCaptureDelim}|(?<unnamed>\()(?!\?)`;
  const token = new RegExp(r$1`${namedCaptureDelim}|${recursiveToken}|\(\?|\\?.`, 'gsu');
  const overlappingRecursionMsg = 'Cannot use multiple overlapping recursions';

  /**
  @param {string} pattern
  @param {{
    flags?: string;
    captureTransfers?: Map<number, Array<number>>;
    hiddenCaptures?: Array<number>;
    mode?: 'plugin' | 'external';
  }} [data]
  @returns {{
    pattern: string;
    captureTransfers: Map<number, Array<number>>;
    hiddenCaptures: Array<number>;
  }}
  */
  function recursion(pattern, data) {
    const {hiddenCaptures, mode} = {
      hiddenCaptures: [],
      mode: 'plugin',
      ...data,
    };
    // Capture transfer is used by <github.com/slevithan/oniguruma-to-es>
    let captureTransfers = data?.captureTransfers ?? new Map();
    // Keep the initial fail-check (which avoids unneeded processing) as fast as possible by testing
    // without the accuracy improvement of using `hasUnescaped` with `Context.DEFAULT`
    if (!(new RegExp(recursiveToken, 'su').test(pattern))) {
      return {
        pattern,
        captureTransfers,
        hiddenCaptures,
      };
    }
    if (mode === 'plugin' && hasUnescaped(pattern, r$1`\(\?\(DEFINE\)`, Context.DEFAULT)) {
      throw new Error('DEFINE groups cannot be used with recursion');
    }

    const addedHiddenCaptures = [];
    const hasNumberedBackref = hasUnescaped(pattern, r$1`\\[1-9]`, Context.DEFAULT);
    const groupContentsStartPos = new Map();
    const openGroups = [];
    let hasRecursed = false;
    let numCharClassesOpen = 0;
    let numCapturesPassed = 0;
    let match;
    token.lastIndex = 0;
    while ((match = token.exec(pattern))) {
      const {0: m, groups: {captureName, rDepth, gRNameOrNum, gRDepth}} = match;
      if (m === '[') {
        numCharClassesOpen++;
      } else if (!numCharClassesOpen) {

        // `(?R=N)`
        if (rDepth) {
          assertMaxInBounds(rDepth);
          if (hasRecursed) {
            throw new Error(overlappingRecursionMsg);
          }
          if (hasNumberedBackref) {
            // Could add support for numbered backrefs with extra effort, but it's probably not worth
            // it. To trigger this error, the regex must include recursion and one of the following:
            // - An interpolated regex that contains a numbered backref (since other numbered
            //   backrefs are prevented by implicit flag n).
            // - A numbered backref, when flag n is explicitly disabled.
            // Note that Regex+'s extended syntax (atomic groups and sometimes subroutines) can also
            // add numbered backrefs, but those work fine because external plugins like this one run
            // *before* the transformation of built-in syntax extensions
            throw new Error(
              // When used in `external` mode by transpilers other than Regex+, backrefs might have
              // gone through conversion from named to numbered, so avoid a misleading error
              `${mode === 'external' ? 'Backrefs' : 'Numbered backrefs'} cannot be used with global recursion`
            );
          }
          const left = pattern.slice(0, match.index);
          const right = pattern.slice(token.lastIndex);
          if (hasUnescaped(right, recursiveToken, Context.DEFAULT)) {
            throw new Error(overlappingRecursionMsg);
          }
          const reps = +rDepth - 1;
          pattern = makeRecursive(
            left,
            right,
            reps,
            false,
            hiddenCaptures,
            addedHiddenCaptures,
            numCapturesPassed
          );
          captureTransfers = mapCaptureTransfers(
            captureTransfers,
            left,
            reps,
            addedHiddenCaptures.length,
            0,
            numCapturesPassed
          );
          // No need to parse further
          break;
        // `\g<name&R=N>`, `\g<number&R=N>`
        } else if (gRNameOrNum) {
          assertMaxInBounds(gRDepth);
          let isWithinReffedGroup = false;
          for (const g of openGroups) {
            if (g.name === gRNameOrNum || g.num === +gRNameOrNum) {
              isWithinReffedGroup = true;
              if (g.hasRecursedWithin) {
                throw new Error(overlappingRecursionMsg);
              }
              break;
            }
          }
          if (!isWithinReffedGroup) {
            throw new Error(r$1`Recursive \g cannot be used outside the referenced group "${
            mode === 'external' ? gRNameOrNum : r$1`\g<${gRNameOrNum}&R=${gRDepth}>`
          }"`);
          }
          const startPos = groupContentsStartPos.get(gRNameOrNum);
          const groupContents = getGroupContents(pattern, startPos);
          if (
            hasNumberedBackref &&
            hasUnescaped(groupContents, r$1`${namedCaptureDelim}|\((?!\?)`, Context.DEFAULT)
          ) {
            throw new Error(
              // When used in `external` mode by transpilers other than Regex+, backrefs might have
              // gone through conversion from named to numbered, so avoid a misleading error
              `${mode === 'external' ? 'Backrefs' : 'Numbered backrefs'} cannot be used with recursion of capturing groups`
            );
          }
          const groupContentsLeft = pattern.slice(startPos, match.index);
          const groupContentsRight = groupContents.slice(groupContentsLeft.length + m.length);
          const numAddedHiddenCapturesPreExpansion = addedHiddenCaptures.length;
          const reps = +gRDepth - 1;
          const expansion = makeRecursive(
            groupContentsLeft,
            groupContentsRight,
            reps,
            true,
            hiddenCaptures,
            addedHiddenCaptures,
            numCapturesPassed
          );
          captureTransfers = mapCaptureTransfers(
            captureTransfers,
            groupContentsLeft,
            reps,
            addedHiddenCaptures.length - numAddedHiddenCapturesPreExpansion,
            numAddedHiddenCapturesPreExpansion,
            numCapturesPassed
          );
          const pre = pattern.slice(0, startPos);
          const post = pattern.slice(startPos + groupContents.length);
          // Modify the string we're looping over
          pattern = `${pre}${expansion}${post}`;
          // Step forward for the next loop iteration
          token.lastIndex += expansion.length - m.length - groupContentsLeft.length - groupContentsRight.length;
          openGroups.forEach(g => g.hasRecursedWithin = true);
          hasRecursed = true;
        } else if (captureName) {
          numCapturesPassed++;
          groupContentsStartPos.set(String(numCapturesPassed), token.lastIndex);
          groupContentsStartPos.set(captureName, token.lastIndex);
          openGroups.push({
            num: numCapturesPassed,
            name: captureName,
          });
        } else if (m[0] === '(') {
          const isUnnamedCapture = m === '(';
          if (isUnnamedCapture) {
            numCapturesPassed++;
            groupContentsStartPos.set(String(numCapturesPassed), token.lastIndex);
          }
          openGroups.push(isUnnamedCapture ? {num: numCapturesPassed} : {});
        } else if (m === ')') {
          openGroups.pop();
        }

      } else if (m === ']') {
        numCharClassesOpen--;
      }
    }

    hiddenCaptures.push(...addedHiddenCaptures);

    return {
      pattern,
      captureTransfers,
      hiddenCaptures,
    };
  }

  /**
  @param {string} max
  */
  function assertMaxInBounds(max) {
    const errMsg = `Max depth must be integer between 2 and 100; used ${max}`;
    if (!/^[1-9]\d*$/.test(max)) {
      throw new Error(errMsg);
    }
    max = +max;
    if (max < 2 || max > 100) {
      throw new Error(errMsg);
    }
  }

  /**
  @param {string} left
  @param {string} right
  @param {number} reps
  @param {boolean} isSubpattern
  @param {Array<number>} hiddenCaptures
  @param {Array<number>} addedHiddenCaptures
  @param {number} numCapturesPassed
  @returns {string}
  */
  function makeRecursive(
    left,
    right,
    reps,
    isSubpattern,
    hiddenCaptures,
    addedHiddenCaptures,
    numCapturesPassed
  ) {
    const namesInRecursed = new Set();
    // Can skip this work if not needed
    if (isSubpattern) {
      forEachUnescaped(left + right, namedCaptureDelim, ({groups: {captureName}}) => {
        namesInRecursed.add(captureName);
      }, Context.DEFAULT);
    }
    const rest = [
      reps,
      isSubpattern ? namesInRecursed : null,
      hiddenCaptures,
      addedHiddenCaptures,
      numCapturesPassed,
    ];
    // Depth 2: 'left(?:left(?:)right)right'
    // Depth 3: 'left(?:left(?:left(?:)right)right)right'
    // Empty group in the middle separates tokens and absorbs a following quantifier if present
    return `${left}${
    repeatWithDepth(`(?:${left}`, 'forward', ...rest)
  }(?:)${
    repeatWithDepth(`${right})`, 'backward', ...rest)
  }${right}`;
  }

  /**
  @param {string} pattern
  @param {'forward' | 'backward'} direction
  @param {number} reps
  @param {Set<string> | null} namesInRecursed
  @param {Array<number>} hiddenCaptures
  @param {Array<number>} addedHiddenCaptures
  @param {number} numCapturesPassed
  @returns {string}
  */
  function repeatWithDepth(
    pattern,
    direction,
    reps,
    namesInRecursed,
    hiddenCaptures,
    addedHiddenCaptures,
    numCapturesPassed
  ) {
    const startNum = 2;
    const getDepthNum = i => direction === 'forward' ? (i + startNum) : (reps - i + startNum - 1);
    let result = '';
    for (let i = 0; i < reps; i++) {
      const depthNum = getDepthNum(i);
      result += replaceUnescaped(
        pattern,
        r$1`${captureDelim}|\\k<(?<backref>[^>]+)>`,
        ({0: m, groups: {captureName, unnamed, backref}}) => {
          if (backref && namesInRecursed && !namesInRecursed.has(backref)) {
            // Don't alter backrefs to groups outside the recursed subpattern
            return m;
          }
          const suffix = `_$${depthNum}`;
          if (unnamed || captureName) {
            const addedCaptureNum = numCapturesPassed + addedHiddenCaptures.length + 1;
            addedHiddenCaptures.push(addedCaptureNum);
            incrementIfAtLeast(hiddenCaptures, addedCaptureNum);
            return unnamed ? m : `(?<${captureName}${suffix}>`;
          }
          return r$1`\k<${backref}${suffix}>`;
        },
        Context.DEFAULT
      );
    }
    return result;
  }

  /**
  Updates the array in place by incrementing each value greater than or equal to the threshold.
  @param {Array<number>} arr
  @param {number} threshold
  */
  function incrementIfAtLeast(arr, threshold) {
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] >= threshold) {
        arr[i]++;
      }
    }
  }

  /**
  @param {Map<number, Array<number>>} captureTransfers
  @param {string} left
  @param {number} reps
  @param {number} numCapturesAddedInExpansion
  @param {number} numAddedHiddenCapturesPreExpansion
  @param {number} numCapturesPassed
  @returns {Map<number, Array<number>>}
  */
  function mapCaptureTransfers(captureTransfers, left, reps, numCapturesAddedInExpansion, numAddedHiddenCapturesPreExpansion, numCapturesPassed) {
    if (captureTransfers.size && numCapturesAddedInExpansion) {
      let numCapturesInLeft = 0;
      forEachUnescaped(left, captureDelim, () => numCapturesInLeft++, Context.DEFAULT);
      // Is 0 for global recursion
      const recursionDelimCaptureNum = numCapturesPassed - numCapturesInLeft + numAddedHiddenCapturesPreExpansion;
      const newCaptureTransfers = new Map();
      captureTransfers.forEach((from, to) => {
        const numCapturesInRight = (numCapturesAddedInExpansion - (numCapturesInLeft * reps)) / reps;
        const numCapturesAddedInLeft = numCapturesInLeft * reps;
        const newTo = to > (recursionDelimCaptureNum + numCapturesInLeft) ? to + numCapturesAddedInExpansion : to;
        const newFrom = [];
        for (const f of from) {
          // Before the recursed subpattern
          if (f <= recursionDelimCaptureNum) {
            newFrom.push(f);
          // After the recursed subpattern
          } else if (f > (recursionDelimCaptureNum + numCapturesInLeft + numCapturesInRight)) {
            newFrom.push(f + numCapturesAddedInExpansion);
          // Within the recursed subpattern, on the left of the recursion token
          } else if (f <= (recursionDelimCaptureNum + numCapturesInLeft)) {
            for (let i = 0; i <= reps; i++) {
              newFrom.push(f + (numCapturesInLeft * i));
            }
          // Within the recursed subpattern, on the right of the recursion token
          } else {
            for (let i = 0; i <= reps; i++) {
              newFrom.push(f + numCapturesAddedInLeft + (numCapturesInRight * i));
            }
          }
        }
        newCaptureTransfers.set(newTo, newFrom);
      });
      return newCaptureTransfers;
    }
    return captureTransfers;
  }

  // src/utils.js
  var cp = String.fromCodePoint;
  var r = String.raw;
  var envFlags = {
    flagGroups: (() => {
      try {
        new RegExp("(?i:)");
      } catch {
        return false;
      }
      return true;
    })(),
    unicodeSets: (() => {
      try {
        new RegExp("[[]]", "v");
      } catch {
        return false;
      }
      return true;
    })()
  };
  envFlags.bugFlagVLiteralHyphenIsRange = envFlags.unicodeSets ? (() => {
    try {
      new RegExp(r`[\d\-a]`, "v");
    } catch {
      return true;
    }
    return false;
  })() : false;
  envFlags.bugNestedClassIgnoresNegation = envFlags.unicodeSets && new RegExp("[[^a]]", "v").test("a");
  function getNewCurrentFlags(current, { enable, disable }) {
    return {
      dotAll: !disable?.dotAll && !!(enable?.dotAll || current.dotAll),
      ignoreCase: !disable?.ignoreCase && !!(enable?.ignoreCase || current.ignoreCase)
    };
  }
  function getOrInsert(map, key, defaultValue) {
    if (!map.has(key)) {
      map.set(key, defaultValue);
    }
    return map.get(key);
  }
  function isMinTarget(target, min) {
    return EsVersion[target] >= EsVersion[min];
  }
  function throwIfNullish(value, msg) {
    if (value == null) {
      throw new Error(msg ?? "Value expected");
    }
    return value;
  }

  // src/options.js
  var EsVersion = {
    ES2025: 2025,
    ES2024: 2024,
    ES2018: 2018
  };
  var Target = (
    /** @type {const} */
    {
      auto: "auto",
      ES2025: "ES2025",
      ES2024: "ES2024",
      ES2018: "ES2018"
    }
  );
  function getOptions(options = {}) {
    if ({}.toString.call(options) !== "[object Object]") {
      throw new Error("Unexpected options");
    }
    if (options.target !== void 0 && !Target[options.target]) {
      throw new Error(`Unexpected target "${options.target}"`);
    }
    const opts = {
      // Sets the level of emulation rigor/strictness.
      accuracy: "default",
      // Disables advanced emulation that relies on returning a `RegExp` subclass, resulting in
      // certain patterns not being emulatable.
      avoidSubclass: false,
      // Oniguruma flags; a string with `i`, `m`, `x`, `D`, `S`, `W`, `y{g}` in any order (all
      // optional). Oniguruma's `m` is equivalent to JavaScript's `s` (`dotAll`).
      flags: "",
      // Include JavaScript flag `g` (`global`) in the result.
      global: false,
      // Include JavaScript flag `d` (`hasIndices`) in the result.
      hasIndices: false,
      // Delay regex construction until first use if the transpiled pattern is at least this length.
      lazyCompileLength: Infinity,
      // JavaScript version used for generated regexes. Using `auto` detects the best value based on
      // your environment. Later targets allow faster processing, simpler generated source, and
      // support for additional features.
      target: "auto",
      // Disables minifications that simplify the pattern without changing the meaning.
      verbose: false,
      ...options,
      // Advanced options that override standard behavior, error checking, and flags when enabled.
      rules: {
        // Useful with TextMate grammars that merge backreferences across patterns.
        allowOrphanBackrefs: false,
        // Use ASCII `\b` and `\B`, which increases search performance of generated regexes.
        asciiWordBoundaries: false,
        // Allow unnamed captures and numbered calls (backreferences and subroutines) when using
        // named capture. This is Oniguruma option `ONIG_OPTION_CAPTURE_GROUP`; on by default in
        // `vscode-oniguruma`.
        captureGroup: false,
        // Change the recursion depth limit from Oniguruma's `20` to an integer `2`–`20`.
        recursionLimit: 20,
        // `^` as `\A`; `$` as`\Z`. Improves search performance of generated regexes without changing
        // the meaning if searching line by line. This is Oniguruma option `ONIG_OPTION_SINGLELINE`.
        singleline: false,
        ...options.rules
      }
    };
    if (opts.target === "auto") {
      opts.target = envFlags.flagGroups ? "ES2025" : envFlags.unicodeSets ? "ES2024" : "ES2018";
    }
    return opts;
  }
  var asciiSpaceChar = "[	-\r ]";
  var CharsWithoutIgnoreCaseExpansion = /* @__PURE__ */ new Set([
    cp(304),
    // İ
    cp(305)
    // ı
  ]);
  var defaultWordChar = r`[\p{L}\p{M}\p{N}\p{Pc}]`;
  function getIgnoreCaseMatchChars(char) {
    if (CharsWithoutIgnoreCaseExpansion.has(char)) {
      return [char];
    }
    const set = /* @__PURE__ */ new Set();
    const lower = char.toLowerCase();
    const upper = lower.toUpperCase();
    const title = LowerToTitleCaseMap.get(lower);
    const altLower = LowerToAlternativeLowerCaseMap.get(lower);
    const altUpper = LowerToAlternativeUpperCaseMap.get(lower);
    if ([...upper].length === 1) {
      set.add(upper);
    }
    altUpper && set.add(altUpper);
    title && set.add(title);
    set.add(lower);
    altLower && set.add(altLower);
    return [...set];
  }
  var JsUnicodePropertyMap = /* @__PURE__ */ new Map(
    `C Other
Cc Control cntrl
Cf Format
Cn Unassigned
Co Private_Use
Cs Surrogate
L Letter
LC Cased_Letter
Ll Lowercase_Letter
Lm Modifier_Letter
Lo Other_Letter
Lt Titlecase_Letter
Lu Uppercase_Letter
M Mark Combining_Mark
Mc Spacing_Mark
Me Enclosing_Mark
Mn Nonspacing_Mark
N Number
Nd Decimal_Number digit
Nl Letter_Number
No Other_Number
P Punctuation punct
Pc Connector_Punctuation
Pd Dash_Punctuation
Pe Close_Punctuation
Pf Final_Punctuation
Pi Initial_Punctuation
Po Other_Punctuation
Ps Open_Punctuation
S Symbol
Sc Currency_Symbol
Sk Modifier_Symbol
Sm Math_Symbol
So Other_Symbol
Z Separator
Zl Line_Separator
Zp Paragraph_Separator
Zs Space_Separator
ASCII
ASCII_Hex_Digit AHex
Alphabetic Alpha
Any
Assigned
Bidi_Control Bidi_C
Bidi_Mirrored Bidi_M
Case_Ignorable CI
Cased
Changes_When_Casefolded CWCF
Changes_When_Casemapped CWCM
Changes_When_Lowercased CWL
Changes_When_NFKC_Casefolded CWKCF
Changes_When_Titlecased CWT
Changes_When_Uppercased CWU
Dash
Default_Ignorable_Code_Point DI
Deprecated Dep
Diacritic Dia
Emoji
Emoji_Component EComp
Emoji_Modifier EMod
Emoji_Modifier_Base EBase
Emoji_Presentation EPres
Extended_Pictographic ExtPict
Extender Ext
Grapheme_Base Gr_Base
Grapheme_Extend Gr_Ext
Hex_Digit Hex
IDS_Binary_Operator IDSB
IDS_Trinary_Operator IDST
ID_Continue IDC
ID_Start IDS
Ideographic Ideo
Join_Control Join_C
Logical_Order_Exception LOE
Lowercase Lower
Math
Noncharacter_Code_Point NChar
Pattern_Syntax Pat_Syn
Pattern_White_Space Pat_WS
Quotation_Mark QMark
Radical
Regional_Indicator RI
Sentence_Terminal STerm
Soft_Dotted SD
Terminal_Punctuation Term
Unified_Ideograph UIdeo
Uppercase Upper
Variation_Selector VS
White_Space space
XID_Continue XIDC
XID_Start XIDS`.split(/\s/).map((p) => [w(p), p])
  );
  var LowerToAlternativeLowerCaseMap = /* @__PURE__ */ new Map([
    ["s", cp(383)],
    // s, ſ
    [cp(383), "s"]
    // ſ, s
  ]);
  var LowerToAlternativeUpperCaseMap = /* @__PURE__ */ new Map([
    [cp(223), cp(7838)],
    // ß, ẞ
    [cp(107), cp(8490)],
    // k, K (Kelvin)
    [cp(229), cp(8491)],
    // å, Å (Angstrom)
    [cp(969), cp(8486)]
    // ω, Ω (Ohm)
  ]);
  var LowerToTitleCaseMap = new Map([
    titleEntry(453),
    titleEntry(456),
    titleEntry(459),
    titleEntry(498),
    ...titleRange(8072, 8079),
    ...titleRange(8088, 8095),
    ...titleRange(8104, 8111),
    titleEntry(8124),
    titleEntry(8140),
    titleEntry(8188)
  ]);
  var PosixClassMap = /* @__PURE__ */ new Map([
    ["alnum", r`[\p{Alpha}\p{Nd}]`],
    ["alpha", r`\p{Alpha}`],
    ["ascii", r`\p{ASCII}`],
    ["blank", r`[\p{Zs}\t]`],
    ["cntrl", r`\p{Cc}`],
    ["digit", r`\p{Nd}`],
    ["graph", r`[\P{space}&&\P{Cc}&&\P{Cn}&&\P{Cs}]`],
    ["lower", r`\p{Lower}`],
    ["print", r`[[\P{space}&&\P{Cc}&&\P{Cn}&&\P{Cs}]\p{Zs}]`],
    ["punct", r`[\p{P}\p{S}]`],
    // Updated value from Onig 6.9.9; changed from Unicode `\p{punct}`
    ["space", r`\p{space}`],
    ["upper", r`\p{Upper}`],
    ["word", r`[\p{Alpha}\p{M}\p{Nd}\p{Pc}]`],
    ["xdigit", r`\p{AHex}`]
  ]);
  function range(start, end) {
    const range2 = [];
    for (let i = start; i <= end; i++) {
      range2.push(i);
    }
    return range2;
  }
  function titleEntry(codePoint) {
    const char = cp(codePoint);
    return [char.toLowerCase(), char];
  }
  function titleRange(start, end) {
    return range(start, end).map((codePoint) => titleEntry(codePoint));
  }
  var UnicodePropertiesWithSpecificCase = /* @__PURE__ */ new Set([
    "Lower",
    "Lowercase",
    "Upper",
    "Uppercase",
    "Ll",
    "Lowercase_Letter",
    "Lt",
    "Titlecase_Letter",
    "Lu",
    "Uppercase_Letter"
    // The `Changes_When_*` properties (and their aliases) could be included, but they're very rare.
    // Some other properties include a handful of chars with specific cases only, but these chars are
    // generally extreme edge cases and using such properties case insensitively generally produces
    // undesired behavior anyway
  ]);
  function transform(ast, options) {
    const opts = {
      // A couple edge cases exist where options `accuracy` and `bestEffortTarget` are used:
      // - `CharacterSet` kind `text_segment` (`\X`): An exact representation would require heavy
      //   Unicode data; a best-effort approximation requires knowing the target.
      // - `CharacterSet` kind `posix` with values `graph` and `print`: Their complex Unicode
      //   representations would be hard to change to ASCII versions after the fact in the generator
      //   based on `target`/`accuracy`, so produce the appropriate structure here.
      accuracy: "default",
      asciiWordBoundaries: false,
      avoidSubclass: false,
      bestEffortTarget: "ES2025",
      ...options
    };
    addParentProperties(ast);
    const firstPassState = {
      accuracy: opts.accuracy,
      asciiWordBoundaries: opts.asciiWordBoundaries,
      avoidSubclass: opts.avoidSubclass,
      flagDirectivesByAlt: /* @__PURE__ */ new Map(),
      jsGroupNameMap: /* @__PURE__ */ new Map(),
      minTargetEs2024: isMinTarget(opts.bestEffortTarget, "ES2024"),
      passedLookbehind: false,
      strategy: null,
      // Subroutines can appear before the groups they ref, so collect reffed nodes for a second pass 
      subroutineRefMap: /* @__PURE__ */ new Map(),
      supportedGNodes: /* @__PURE__ */ new Set(),
      digitIsAscii: ast.flags.digitIsAscii,
      spaceIsAscii: ast.flags.spaceIsAscii,
      wordIsAscii: ast.flags.wordIsAscii
    };
    S(ast, FirstPassVisitor, firstPassState);
    const globalFlags = {
      dotAll: ast.flags.dotAll,
      ignoreCase: ast.flags.ignoreCase
    };
    const secondPassState = {
      currentFlags: globalFlags,
      prevFlags: null,
      globalFlags,
      groupOriginByCopy: /* @__PURE__ */ new Map(),
      groupsByName: /* @__PURE__ */ new Map(),
      multiplexCapturesToLeftByRef: /* @__PURE__ */ new Map(),
      openRefs: /* @__PURE__ */ new Map(),
      reffedNodesByReferencer: /* @__PURE__ */ new Map(),
      subroutineRefMap: firstPassState.subroutineRefMap
    };
    S(ast, SecondPassVisitor, secondPassState);
    const thirdPassState = {
      groupsByName: secondPassState.groupsByName,
      highestOrphanBackref: 0,
      numCapturesToLeft: 0,
      reffedNodesByReferencer: secondPassState.reffedNodesByReferencer
    };
    S(ast, ThirdPassVisitor, thirdPassState);
    ast._originMap = secondPassState.groupOriginByCopy;
    ast._strategy = firstPassState.strategy;
    return ast;
  }
  var FirstPassVisitor = {
    AbsenceFunction({ node, parent, replaceWith }) {
      const { body, kind } = node;
      if (kind === "repeater") {
        const innerGroup = A();
        innerGroup.body[0].body.push(
          // Insert own alts as `body`
          K({ negate: true, body }),
          Q("Any")
        );
        const outerGroup = A();
        outerGroup.body[0].body.push(
          _("greedy", 0, Infinity, innerGroup)
        );
        replaceWith(setParentDeep(outerGroup, parent), { traverse: true });
      } else {
        throw new Error(`Unsupported absence function "(?~|"`);
      }
    },
    Alternative: {
      enter({ node, parent, key }, { flagDirectivesByAlt }) {
        const flagDirectives = node.body.filter((el) => el.kind === "flags");
        for (let i = key + 1; i < parent.body.length; i++) {
          const forwardSiblingAlt = parent.body[i];
          getOrInsert(flagDirectivesByAlt, forwardSiblingAlt, []).push(...flagDirectives);
        }
      },
      exit({ node }, { flagDirectivesByAlt }) {
        if (flagDirectivesByAlt.get(node)?.length) {
          const flags = getCombinedFlagModsFromFlagNodes(flagDirectivesByAlt.get(node));
          if (flags) {
            const flagGroup = A({ flags });
            flagGroup.body[0].body = node.body;
            node.body = [setParentDeep(flagGroup, node)];
          }
        }
      }
    },
    Assertion({ node, parent, key, container, root, remove, replaceWith }, state) {
      const { kind, negate } = node;
      const { asciiWordBoundaries, avoidSubclass, supportedGNodes, wordIsAscii } = state;
      if (kind === "text_segment_boundary") {
        throw new Error(`Unsupported text segment boundary "\\${negate ? "Y" : "y"}"`);
      } else if (kind === "line_end") {
        replaceWith(setParentDeep(K({ body: [
          b({ body: [F("string_end")] }),
          b({ body: [m(10)] })
          // `\n`
        ] }), parent));
      } else if (kind === "line_start") {
        replaceWith(setParentDeep(parseFragment(r`(?<=\A|\n(?!\z))`, { skipLookbehindValidation: true }), parent));
      } else if (kind === "search_start") {
        if (supportedGNodes.has(node)) {
          root.flags.sticky = true;
          remove();
        } else {
          const prev = container[key - 1];
          if (prev && isAlwaysNonZeroLength(prev)) {
            replaceWith(setParentDeep(K({ negate: true }), parent));
          } else if (avoidSubclass) {
            throw new Error(r`Uses "\G" in a way that requires a subclass`);
          } else {
            replaceWith(setParent(F("string_start"), parent));
            state.strategy = "clip_search";
          }
        }
      } else if (kind === "string_end" || kind === "string_start") ; else if (kind === "string_end_newline") {
        replaceWith(setParentDeep(parseFragment(r`(?=\n?\z)`), parent));
      } else if (kind === "word_boundary") {
        if (!wordIsAscii && !asciiWordBoundaries) {
          const b = `(?:(?<=${defaultWordChar})(?!${defaultWordChar})|(?<!${defaultWordChar})(?=${defaultWordChar}))`;
          const B = `(?:(?<=${defaultWordChar})(?=${defaultWordChar})|(?<!${defaultWordChar})(?!${defaultWordChar}))`;
          replaceWith(setParentDeep(parseFragment(negate ? B : b), parent));
        }
      } else {
        throw new Error(`Unexpected assertion kind "${kind}"`);
      }
    },
    Backreference({ node }, { jsGroupNameMap }) {
      let { ref } = node;
      if (typeof ref === "string" && !isValidJsGroupName(ref)) {
        ref = getAndStoreJsGroupName(ref, jsGroupNameMap);
        node.ref = ref;
      }
    },
    CapturingGroup({ node }, { jsGroupNameMap, subroutineRefMap }) {
      let { name } = node;
      if (name && !isValidJsGroupName(name)) {
        name = getAndStoreJsGroupName(name, jsGroupNameMap);
        node.name = name;
      }
      subroutineRefMap.set(node.number, node);
      if (name) {
        subroutineRefMap.set(name, node);
      }
    },
    CharacterClassRange({ node, parent, replaceWith }) {
      if (parent.kind === "intersection") {
        const cc = C({ body: [node] });
        replaceWith(setParentDeep(cc, parent), { traverse: true });
      }
    },
    CharacterSet({ node, parent, replaceWith }, { accuracy, minTargetEs2024, digitIsAscii, spaceIsAscii, wordIsAscii }) {
      const { kind, negate, value } = node;
      if (digitIsAscii && (kind === "digit" || value === "digit")) {
        replaceWith(setParent(E("digit", { negate }), parent));
        return;
      }
      if (spaceIsAscii && (kind === "space" || value === "space")) {
        replaceWith(setParentDeep(setNegate(parseFragment(asciiSpaceChar), negate), parent));
        return;
      }
      if (wordIsAscii && (kind === "word" || value === "word")) {
        replaceWith(setParent(E("word", { negate }), parent));
        return;
      }
      if (kind === "any") {
        replaceWith(setParent(Q("Any"), parent));
      } else if (kind === "digit") {
        replaceWith(setParent(Q("Nd", { negate }), parent));
      } else if (kind === "dot") ; else if (kind === "text_segment") {
        if (accuracy === "strict") {
          throw new Error(r`Use of "\X" requires non-strict accuracy`);
        }
        const eBase = "\\p{Emoji}(?:\\p{EMod}|\\uFE0F\\u20E3?|[\\x{E0020}-\\x{E007E}]+\\x{E007F})?";
        const emoji = r`\p{RI}{2}|${eBase}(?:\u200D${eBase})*`;
        replaceWith(setParentDeep(parseFragment(
          // Close approximation of an extended grapheme cluster; see <unicode.org/reports/tr29/>
          r`(?>\r\n|${minTargetEs2024 ? r`\p{RGI_Emoji}` : emoji}|\P{M}\p{M}*)`,
          // Allow JS property `RGI_Emoji` through
          { skipPropertyNameValidation: true }
        ), parent));
      } else if (kind === "hex") {
        replaceWith(setParent(Q("AHex", { negate }), parent));
      } else if (kind === "newline") {
        replaceWith(setParentDeep(parseFragment(negate ? "[^\n]" : "(?>\r\n?|[\n\v\f\x85\u2028\u2029])"), parent));
      } else if (kind === "posix") {
        if (!minTargetEs2024 && (value === "graph" || value === "print")) {
          if (accuracy === "strict") {
            throw new Error(`POSIX class "${value}" requires min target ES2024 or non-strict accuracy`);
          }
          let ascii = {
            graph: "!-~",
            print: " -~"
          }[value];
          if (negate) {
            ascii = `\0-${cp(ascii.codePointAt(0) - 1)}${cp(ascii.codePointAt(2) + 1)}-\u{10FFFF}`;
          }
          replaceWith(setParentDeep(parseFragment(`[${ascii}]`), parent));
        } else {
          replaceWith(setParentDeep(setNegate(parseFragment(PosixClassMap.get(value)), negate), parent));
        }
      } else if (kind === "property") {
        if (!JsUnicodePropertyMap.has(w(value))) {
          node.key = "sc";
        }
      } else if (kind === "space") {
        replaceWith(setParent(Q("space", { negate }), parent));
      } else if (kind === "word") {
        replaceWith(setParentDeep(setNegate(parseFragment(defaultWordChar), negate), parent));
      } else {
        throw new Error(`Unexpected character set kind "${kind}"`);
      }
    },
    Directive({ node, parent, root, remove, replaceWith, removeAllPrevSiblings, removeAllNextSiblings }) {
      const { kind, flags } = node;
      if (kind === "flags") {
        if (!flags.enable && !flags.disable) {
          remove();
        } else {
          const flagGroup = A({ flags });
          flagGroup.body[0].body = removeAllNextSiblings();
          replaceWith(setParentDeep(flagGroup, parent), { traverse: true });
        }
      } else if (kind === "keep") {
        const firstAlt = root.body[0];
        const hasWrapperGroup = root.body.length === 1 && // Not emulatable if within a `CapturingGroup`
        o(firstAlt, { type: "Group" }) && firstAlt.body[0].body.length === 1;
        const topLevel = hasWrapperGroup ? firstAlt.body[0] : root;
        if (parent.parent !== topLevel || topLevel.body.length > 1) {
          throw new Error(r`Uses "\K" in a way that's unsupported`);
        }
        const lookbehind = K({ behind: true });
        lookbehind.body[0].body = removeAllPrevSiblings();
        replaceWith(setParentDeep(lookbehind, parent));
      } else {
        throw new Error(`Unexpected directive kind "${kind}"`);
      }
    },
    Flags({ node, parent }) {
      if (node.posixIsAscii) {
        throw new Error('Unsupported flag "P"');
      }
      if (node.textSegmentMode === "word") {
        throw new Error('Unsupported flag "y{w}"');
      }
      [
        "digitIsAscii",
        // Flag D
        "extended",
        // Flag x
        "posixIsAscii",
        // Flag P
        "spaceIsAscii",
        // Flag S
        "wordIsAscii",
        // Flag W
        "textSegmentMode"
        // Flag y{g} or y{w}
      ].forEach((f) => delete node[f]);
      Object.assign(node, {
        // JS flag g; no Onig equiv
        global: false,
        // JS flag d; no Onig equiv
        hasIndices: false,
        // JS flag m; no Onig equiv but its behavior is always on in Onig. Onig's only line break
        // char is line feed, unlike JS, so this flag isn't used since it would produce inaccurate
        // results (also allows `^` and `$` to be used in the generator for string start and end)
        multiline: false,
        // JS flag y; no Onig equiv, but used for `\G` emulation
        sticky: node.sticky ?? false
        // Note: Regex+ doesn't allow explicitly adding flags it handles implicitly, so leave out
        // properties `unicode` (JS flag u) and `unicodeSets` (JS flag v). Keep the existing values
        // for `ignoreCase` (flag i) and `dotAll` (JS flag s, but Onig flag m)
      });
      parent.options = {
        disable: {
          // Onig uses different rules for flag x than Regex+, so disable the implicit flag
          x: true,
          // Onig has no flag to control "named capture only" mode but contextually applies its
          // behavior when named capturing is used, so disable Regex+'s implicit flag for it
          n: true
        },
        force: {
          // Always add flag v because we're generating an AST that relies on it (it enables JS
          // support for Onig features nested classes, intersection, Unicode properties, etc.).
          // However, the generator might disable flag v based on its `target` option
          v: true
        }
      };
    },
    Group({ node }) {
      if (!node.flags) {
        return;
      }
      const { enable, disable } = node.flags;
      enable?.extended && delete enable.extended;
      disable?.extended && delete disable.extended;
      enable?.dotAll && disable?.dotAll && delete enable.dotAll;
      enable?.ignoreCase && disable?.ignoreCase && delete enable.ignoreCase;
      enable && !Object.keys(enable).length && delete node.flags.enable;
      disable && !Object.keys(disable).length && delete node.flags.disable;
      !node.flags.enable && !node.flags.disable && delete node.flags;
    },
    LookaroundAssertion({ node }, state) {
      const { kind } = node;
      if (kind === "lookbehind") {
        state.passedLookbehind = true;
      }
    },
    NamedCallout({ node, parent, replaceWith }) {
      const { kind } = node;
      if (kind === "fail") {
        replaceWith(setParentDeep(K({ negate: true }), parent));
      } else {
        throw new Error(`Unsupported named callout "(*${kind.toUpperCase()}"`);
      }
    },
    Quantifier({ node }) {
      if (node.body.type === "Quantifier") {
        const group = A();
        group.body[0].body.push(node.body);
        node.body = setParentDeep(group, node);
      }
    },
    Regex: {
      enter({ node }, { supportedGNodes }) {
        const leadingGs = [];
        let hasAltWithLeadG = false;
        let hasAltWithoutLeadG = false;
        for (const alt of node.body) {
          if (alt.body.length === 1 && alt.body[0].kind === "search_start") {
            alt.body.pop();
          } else {
            const leadingG = getLeadingG(alt.body);
            if (leadingG) {
              hasAltWithLeadG = true;
              Array.isArray(leadingG) ? leadingGs.push(...leadingG) : leadingGs.push(leadingG);
            } else {
              hasAltWithoutLeadG = true;
            }
          }
        }
        if (hasAltWithLeadG && !hasAltWithoutLeadG) {
          leadingGs.forEach((g) => supportedGNodes.add(g));
        }
      },
      exit(_, { accuracy, passedLookbehind, strategy }) {
        if (accuracy === "strict" && passedLookbehind && strategy) {
          throw new Error(r`Uses "\G" in a way that requires non-strict accuracy`);
        }
      }
    },
    Subroutine({ node }, { jsGroupNameMap }) {
      let { ref } = node;
      if (typeof ref === "string" && !isValidJsGroupName(ref)) {
        ref = getAndStoreJsGroupName(ref, jsGroupNameMap);
        node.ref = ref;
      }
    }
  };
  var SecondPassVisitor = {
    Backreference({ node }, { multiplexCapturesToLeftByRef, reffedNodesByReferencer }) {
      const { orphan, ref } = node;
      if (!orphan) {
        reffedNodesByReferencer.set(node, [...multiplexCapturesToLeftByRef.get(ref).map(({ node: node2 }) => node2)]);
      }
    },
    CapturingGroup: {
      enter({
        node,
        parent,
        replaceWith,
        skip
      }, {
        groupOriginByCopy,
        groupsByName,
        multiplexCapturesToLeftByRef,
        openRefs,
        reffedNodesByReferencer
      }) {
        const origin = groupOriginByCopy.get(node);
        if (origin && openRefs.has(node.number)) {
          const recursion2 = setParent(createRecursion(node.number), parent);
          reffedNodesByReferencer.set(recursion2, openRefs.get(node.number));
          replaceWith(recursion2);
          return;
        }
        openRefs.set(node.number, node);
        multiplexCapturesToLeftByRef.set(node.number, []);
        if (node.name) {
          getOrInsert(multiplexCapturesToLeftByRef, node.name, []);
        }
        const multiplexNodes = multiplexCapturesToLeftByRef.get(node.name ?? node.number);
        for (let i = 0; i < multiplexNodes.length; i++) {
          const multiplex = multiplexNodes[i];
          if (
            // This group is from subroutine expansion, and there's a multiplex value from either the
            // origin node or a prior subroutine expansion group with the same origin
            origin === multiplex.node || origin && origin === multiplex.origin || // This group is not from subroutine expansion, and it comes after a subroutine expansion
            // group that refers to this group
            node === multiplex.origin
          ) {
            multiplexNodes.splice(i, 1);
            break;
          }
        }
        multiplexCapturesToLeftByRef.get(node.number).push({ node, origin });
        if (node.name) {
          multiplexCapturesToLeftByRef.get(node.name).push({ node, origin });
        }
        if (node.name) {
          const groupsWithSameName = getOrInsert(groupsByName, node.name, /* @__PURE__ */ new Map());
          let hasDuplicateNameToRemove = false;
          if (origin) {
            hasDuplicateNameToRemove = true;
          } else {
            for (const groupInfo of groupsWithSameName.values()) {
              if (!groupInfo.hasDuplicateNameToRemove) {
                hasDuplicateNameToRemove = true;
                break;
              }
            }
          }
          groupsByName.get(node.name).set(node, { node, hasDuplicateNameToRemove });
        }
      },
      exit({ node }, { openRefs }) {
        openRefs.delete(node.number);
      }
    },
    Group: {
      enter({ node }, state) {
        state.prevFlags = state.currentFlags;
        if (node.flags) {
          state.currentFlags = getNewCurrentFlags(state.currentFlags, node.flags);
        }
      },
      exit(_, state) {
        state.currentFlags = state.prevFlags;
      }
    },
    Subroutine({ node, parent, replaceWith }, state) {
      const { isRecursive, ref } = node;
      if (isRecursive) {
        let reffed = parent;
        while (reffed = reffed.parent) {
          if (reffed.type === "CapturingGroup" && (reffed.name === ref || reffed.number === ref)) {
            break;
          }
        }
        state.reffedNodesByReferencer.set(node, reffed);
        return;
      }
      const reffedGroupNode = state.subroutineRefMap.get(ref);
      const isGlobalRecursion = ref === 0;
      const expandedSubroutine = isGlobalRecursion ? createRecursion(0) : (
        // The reffed group might itself contain subroutines, which are expanded during sub-traversal
        cloneCapturingGroup(reffedGroupNode, state.groupOriginByCopy, null)
      );
      let replacement = expandedSubroutine;
      if (!isGlobalRecursion) {
        const reffedGroupFlagMods = getCombinedFlagModsFromFlagNodes(getAllParents(
          reffedGroupNode,
          (p) => p.type === "Group" && !!p.flags
        ));
        const reffedGroupFlags = reffedGroupFlagMods ? getNewCurrentFlags(state.globalFlags, reffedGroupFlagMods) : state.globalFlags;
        if (!areFlagsEqual(reffedGroupFlags, state.currentFlags)) {
          replacement = A({
            flags: getFlagModsFromFlags(reffedGroupFlags)
          });
          replacement.body[0].body.push(expandedSubroutine);
        }
      }
      replaceWith(setParentDeep(replacement, parent), { traverse: !isGlobalRecursion });
    }
  };
  var ThirdPassVisitor = {
    Backreference({ node, parent, replaceWith }, state) {
      if (node.orphan) {
        state.highestOrphanBackref = Math.max(state.highestOrphanBackref, node.ref);
        return;
      }
      const reffedNodes = state.reffedNodesByReferencer.get(node);
      const participants = reffedNodes.filter((reffed) => canParticipateWithNode(reffed, node));
      if (!participants.length) {
        replaceWith(setParentDeep(K({ negate: true }), parent));
      } else if (participants.length > 1) {
        const group = A({
          atomic: true,
          body: participants.reverse().map((reffed) => b({
            body: [k(reffed.number)]
          }))
        });
        replaceWith(setParentDeep(group, parent));
      } else {
        node.ref = participants[0].number;
      }
    },
    CapturingGroup({ node }, state) {
      node.number = ++state.numCapturesToLeft;
      if (node.name) {
        if (state.groupsByName.get(node.name).get(node).hasDuplicateNameToRemove) {
          delete node.name;
        }
      }
    },
    Regex: {
      exit({ node }, state) {
        const numCapsNeeded = Math.max(state.highestOrphanBackref - state.numCapturesToLeft, 0);
        for (let i = 0; i < numCapsNeeded; i++) {
          const emptyCapture = P();
          node.body.at(-1).body.push(emptyCapture);
        }
      }
    },
    Subroutine({ node }, state) {
      if (!node.isRecursive || node.ref === 0) {
        return;
      }
      node.ref = state.reffedNodesByReferencer.get(node).number;
    }
  };
  function addParentProperties(root) {
    S(root, {
      "*"({ node, parent }) {
        node.parent = parent;
      }
    });
  }
  function areFlagsEqual(a, b) {
    return a.dotAll === b.dotAll && a.ignoreCase === b.ignoreCase;
  }
  function canParticipateWithNode(capture, node) {
    let rightmostPoint = node;
    do {
      if (rightmostPoint.type === "Regex") {
        return false;
      }
      if (rightmostPoint.type === "Alternative") {
        continue;
      }
      if (rightmostPoint === capture) {
        return false;
      }
      const kidsOfParent = getKids(rightmostPoint.parent);
      for (const kid of kidsOfParent) {
        if (kid === rightmostPoint) {
          break;
        }
        if (kid === capture || isAncestorOf(kid, capture)) {
          return true;
        }
      }
    } while (rightmostPoint = rightmostPoint.parent);
    throw new Error("Unexpected path");
  }
  function cloneCapturingGroup(obj, originMap, up, up2) {
    const store = Array.isArray(obj) ? [] : {};
    for (const [key, value] of Object.entries(obj)) {
      if (key === "parent") {
        store.parent = Array.isArray(up) ? up2 : up;
      } else if (value && typeof value === "object") {
        store[key] = cloneCapturingGroup(value, originMap, store, up);
      } else {
        if (key === "type" && value === "CapturingGroup") {
          originMap.set(store, originMap.get(obj) ?? obj);
        }
        store[key] = value;
      }
    }
    return store;
  }
  function createRecursion(ref) {
    const node = O(ref);
    node.isRecursive = true;
    return node;
  }
  function getAllParents(node, filterFn) {
    const results = [];
    while (node = node.parent) {
      if (!filterFn || filterFn(node)) {
        results.push(node);
      }
    }
    return results;
  }
  function getAndStoreJsGroupName(name, map) {
    if (map.has(name)) {
      return map.get(name);
    }
    const jsName = `$${map.size}_${name.replace(/^[^$_\p{IDS}]|[^$\u200C\u200D\p{IDC}]/ug, "_")}`;
    map.set(name, jsName);
    return jsName;
  }
  function getCombinedFlagModsFromFlagNodes(flagNodes) {
    const flagProps = ["dotAll", "ignoreCase"];
    const combinedFlags = { enable: {}, disable: {} };
    flagNodes.forEach(({ flags }) => {
      flagProps.forEach((prop) => {
        if (flags.enable?.[prop]) {
          delete combinedFlags.disable[prop];
          combinedFlags.enable[prop] = true;
        }
        if (flags.disable?.[prop]) {
          combinedFlags.disable[prop] = true;
        }
      });
    });
    if (!Object.keys(combinedFlags.enable).length) {
      delete combinedFlags.enable;
    }
    if (!Object.keys(combinedFlags.disable).length) {
      delete combinedFlags.disable;
    }
    if (combinedFlags.enable || combinedFlags.disable) {
      return combinedFlags;
    }
    return null;
  }
  function getFlagModsFromFlags({ dotAll, ignoreCase }) {
    const mods = {};
    if (dotAll || ignoreCase) {
      mods.enable = {};
      dotAll && (mods.enable.dotAll = true);
      ignoreCase && (mods.enable.ignoreCase = true);
    }
    if (!dotAll || !ignoreCase) {
      mods.disable = {};
      !dotAll && (mods.disable.dotAll = true);
      !ignoreCase && (mods.disable.ignoreCase = true);
    }
    return mods;
  }
  function getKids(node) {
    if (!node) {
      throw new Error("Node expected");
    }
    const { body } = node;
    return Array.isArray(body) ? body : body ? [body] : null;
  }
  function getLeadingG(els) {
    const firstToConsider = els.find((el) => el.kind === "search_start" || isLoneGLookaround(el, { negate: false }) || !isAlwaysZeroLength(el));
    if (!firstToConsider) {
      return null;
    }
    if (firstToConsider.kind === "search_start") {
      return firstToConsider;
    }
    if (firstToConsider.type === "LookaroundAssertion") {
      return firstToConsider.body[0].body[0];
    }
    if (firstToConsider.type === "CapturingGroup" || firstToConsider.type === "Group") {
      const gNodesForGroup = [];
      for (const alt of firstToConsider.body) {
        const leadingG = getLeadingG(alt.body);
        if (!leadingG) {
          return null;
        }
        Array.isArray(leadingG) ? gNodesForGroup.push(...leadingG) : gNodesForGroup.push(leadingG);
      }
      return gNodesForGroup;
    }
    return null;
  }
  function isAncestorOf(node, descendant) {
    const kids = getKids(node) ?? [];
    for (const kid of kids) {
      if (kid === descendant || isAncestorOf(kid, descendant)) {
        return true;
      }
    }
    return false;
  }
  function isAlwaysZeroLength({ type }) {
    return type === "Assertion" || type === "Directive" || type === "LookaroundAssertion";
  }
  function isAlwaysNonZeroLength(node) {
    const types = [
      "Character",
      "CharacterClass",
      "CharacterSet"
    ];
    return types.includes(node.type) || node.type === "Quantifier" && node.min && types.includes(node.body.type);
  }
  function isLoneGLookaround(node, options) {
    const opts = {
      negate: null,
      ...options
    };
    return node.type === "LookaroundAssertion" && (opts.negate === null || node.negate === opts.negate) && node.body.length === 1 && o(node.body[0], {
      type: "Assertion",
      kind: "search_start"
    });
  }
  function isValidJsGroupName(name) {
    return /^[$_\p{IDS}][$\u200C\u200D\p{IDC}]*$/u.test(name);
  }
  function parseFragment(pattern, options) {
    const ast = J(pattern, {
      ...options,
      // Providing a custom set of Unicode property names avoids converting some JS Unicode
      // properties (ex: `\p{Alpha}`) to Onig POSIX classes
      unicodePropertyMap: JsUnicodePropertyMap
    });
    const alts = ast.body;
    if (alts.length > 1 || alts[0].body.length > 1) {
      return A({ body: alts });
    }
    return alts[0].body[0];
  }
  function setNegate(node, negate) {
    node.negate = negate;
    return node;
  }
  function setParent(node, parent) {
    node.parent = parent;
    return node;
  }
  function setParentDeep(node, parent) {
    addParentProperties(node);
    node.parent = parent;
    return node;
  }
  function generate(ast, options) {
    const opts = getOptions(options);
    const minTargetEs2024 = isMinTarget(opts.target, "ES2024");
    const minTargetEs2025 = isMinTarget(opts.target, "ES2025");
    const recursionLimit = opts.rules.recursionLimit;
    if (!Number.isInteger(recursionLimit) || recursionLimit < 2 || recursionLimit > 20) {
      throw new Error("Invalid recursionLimit; use 2-20");
    }
    let hasCaseInsensitiveNode = null;
    let hasCaseSensitiveNode = null;
    if (!minTargetEs2025) {
      const iStack = [ast.flags.ignoreCase];
      S(ast, FlagModifierVisitor, {
        getCurrentModI: () => iStack.at(-1),
        popModI() {
          iStack.pop();
        },
        pushModI(isIOn) {
          iStack.push(isIOn);
        },
        setHasCasedChar() {
          if (iStack.at(-1)) {
            hasCaseInsensitiveNode = true;
          } else {
            hasCaseSensitiveNode = true;
          }
        }
      });
    }
    const appliedGlobalFlags = {
      dotAll: ast.flags.dotAll,
      // - Turn global flag i on if a case insensitive node was used and no case sensitive nodes were
      //   used (to avoid unnecessary node expansion).
      // - Turn global flag i off if a case sensitive node was used (since case sensitivity can't be
      //   forced without the use of ES2025 flag groups)
      ignoreCase: !!((ast.flags.ignoreCase || hasCaseInsensitiveNode) && !hasCaseSensitiveNode)
    };
    let lastNode = ast;
    const state = {
      accuracy: opts.accuracy,
      appliedGlobalFlags,
      captureMap: /* @__PURE__ */ new Map(),
      currentFlags: {
        dotAll: ast.flags.dotAll,
        ignoreCase: ast.flags.ignoreCase
      },
      inCharClass: false,
      lastNode,
      originMap: ast._originMap,
      recursionLimit,
      useAppliedIgnoreCase: !!(!minTargetEs2025 && hasCaseInsensitiveNode && hasCaseSensitiveNode),
      useFlagMods: minTargetEs2025,
      useFlagV: minTargetEs2024,
      verbose: opts.verbose
    };
    function gen(node) {
      state.lastNode = lastNode;
      lastNode = node;
      const fn = throwIfNullish(generator[node.type], `Unexpected node type "${node.type}"`);
      return fn(node, state, gen);
    }
    const result = {
      pattern: ast.body.map(gen).join("|"),
      // Could reset `lastNode` at this point via `lastNode = ast`, but it isn't needed by flags
      flags: gen(ast.flags),
      options: { ...ast.options }
    };
    if (!minTargetEs2024) {
      delete result.options.force.v;
      result.options.disable.v = true;
      result.options.unicodeSetsPlugin = null;
    }
    result._captureTransfers = /* @__PURE__ */ new Map();
    result._hiddenCaptures = [];
    state.captureMap.forEach((value, key) => {
      if (value.hidden) {
        result._hiddenCaptures.push(key);
      }
      if (value.transferTo) {
        getOrInsert(result._captureTransfers, value.transferTo, []).push(key);
      }
    });
    return result;
  }
  var FlagModifierVisitor = {
    "*": {
      enter({ node }, state) {
        if (isAnyGroup(node)) {
          const currentModI = state.getCurrentModI();
          state.pushModI(
            node.flags ? getNewCurrentFlags({ ignoreCase: currentModI }, node.flags).ignoreCase : currentModI
          );
        }
      },
      exit({ node }, state) {
        if (isAnyGroup(node)) {
          state.popModI();
        }
      }
    },
    Backreference(_, state) {
      state.setHasCasedChar();
    },
    Character({ node }, state) {
      if (charHasCase(cp(node.value))) {
        state.setHasCasedChar();
      }
    },
    CharacterClassRange({ node, skip }, state) {
      skip();
      if (getCasesOutsideCharClassRange(node, { firstOnly: true }).length) {
        state.setHasCasedChar();
      }
    },
    CharacterSet({ node }, state) {
      if (node.kind === "property" && UnicodePropertiesWithSpecificCase.has(node.value)) {
        state.setHasCasedChar();
      }
    }
  };
  var generator = {
    /**
    @param {AlternativeNode} node
    */
    Alternative({ body }, _, gen) {
      return body.map(gen).join("");
    },
    /**
    @param {AssertionNode} node
    */
    Assertion({ kind, negate }) {
      if (kind === "string_end") {
        return "$";
      }
      if (kind === "string_start") {
        return "^";
      }
      if (kind === "word_boundary") {
        return negate ? r`\B` : r`\b`;
      }
      throw new Error(`Unexpected assertion kind "${kind}"`);
    },
    /**
    @param {BackreferenceNode} node
    */
    Backreference({ ref }, state) {
      if (typeof ref !== "number") {
        throw new Error("Unexpected named backref in transformed AST");
      }
      if (!state.useFlagMods && state.accuracy === "strict" && state.currentFlags.ignoreCase && !state.captureMap.get(ref).ignoreCase) {
        throw new Error("Use of case-insensitive backref to case-sensitive group requires target ES2025 or non-strict accuracy");
      }
      return "\\" + ref;
    },
    /**
    @param {CapturingGroupNode} node
    */
    CapturingGroup(node, state, gen) {
      const { body, name, number } = node;
      const data = { ignoreCase: state.currentFlags.ignoreCase };
      const origin = state.originMap.get(node);
      if (origin) {
        data.hidden = true;
        if (number > origin.number) {
          data.transferTo = origin.number;
        }
      }
      state.captureMap.set(number, data);
      return `(${name ? `?<${name}>` : ""}${body.map(gen).join("|")})`;
    },
    /**
    @param {CharacterNode} node
    */
    Character({ value }, state) {
      const char = cp(value);
      const escaped = getCharEscape(value, {
        escDigit: state.lastNode.type === "Backreference",
        inCharClass: state.inCharClass,
        useFlagV: state.useFlagV
      });
      if (escaped !== char) {
        return escaped;
      }
      if (state.useAppliedIgnoreCase && state.currentFlags.ignoreCase && charHasCase(char)) {
        const cases = getIgnoreCaseMatchChars(char);
        return state.inCharClass ? cases.join("") : cases.length > 1 ? `[${cases.join("")}]` : cases[0];
      }
      return char;
    },
    /**
    @param {CharacterClassNode} node
    */
    CharacterClass(node, state, gen) {
      const { kind, negate, parent } = node;
      let { body } = node;
      if (kind === "intersection" && !state.useFlagV) {
        throw new Error("Use of character class intersection requires min target ES2024");
      }
      if (envFlags.bugFlagVLiteralHyphenIsRange && state.useFlagV && body.some(isLiteralHyphen)) {
        body = [m(45), ...body.filter((kid) => !isLiteralHyphen(kid))];
      }
      const genClass = () => `[${negate ? "^" : ""}${body.map(gen).join(kind === "intersection" ? "&&" : "")}]`;
      if (!state.inCharClass) {
        if (
          // Already established `kind !== 'intersection'` if `!state.useFlagV`; don't check again
          (!state.useFlagV || envFlags.bugNestedClassIgnoresNegation) && !negate
        ) {
          const negatedChildClasses = body.filter(
            (kid) => kid.type === "CharacterClass" && kid.kind === "union" && kid.negate
          );
          if (negatedChildClasses.length) {
            const group = A();
            const groupFirstAlt = group.body[0];
            group.parent = parent;
            groupFirstAlt.parent = group;
            body = body.filter((kid) => !negatedChildClasses.includes(kid));
            node.body = body;
            if (body.length) {
              node.parent = groupFirstAlt;
              groupFirstAlt.body.push(node);
            } else {
              group.body.pop();
            }
            negatedChildClasses.forEach((cc) => {
              const newAlt = b({ body: [cc] });
              cc.parent = newAlt;
              newAlt.parent = group;
              group.body.push(newAlt);
            });
            return gen(group);
          }
        }
        state.inCharClass = true;
        const result = genClass();
        state.inCharClass = false;
        return result;
      }
      const firstEl = body[0];
      if (
        // Already established that the parent is a char class via `inCharClass`; don't check again
        kind === "union" && !negate && firstEl && // Allows many nested classes to work with `target` ES2018 which doesn't support nesting
        ((!state.useFlagV || !state.verbose) && parent.kind === "union" && !(envFlags.bugFlagVLiteralHyphenIsRange && state.useFlagV) || !state.verbose && parent.kind === "intersection" && // JS doesn't allow intersection with union or ranges
        body.length === 1 && firstEl.type !== "CharacterClassRange")
      ) {
        return body.map(gen).join("");
      }
      if (!state.useFlagV && parent.type === "CharacterClass") {
        throw new Error("Uses nested character class in a way that requires min target ES2024");
      }
      return genClass();
    },
    /**
    @param {CharacterClassRangeNode} node
    */
    CharacterClassRange(node, state) {
      const min = node.min.value;
      const max = node.max.value;
      const escOpts = {
        escDigit: false,
        inCharClass: true,
        useFlagV: state.useFlagV
      };
      const minStr = getCharEscape(min, escOpts);
      const maxStr = getCharEscape(max, escOpts);
      const extraChars = /* @__PURE__ */ new Set();
      if (state.useAppliedIgnoreCase && state.currentFlags.ignoreCase) {
        const charsOutsideRange = getCasesOutsideCharClassRange(node);
        const ranges = getCodePointRangesFromChars(charsOutsideRange);
        ranges.forEach((value) => {
          extraChars.add(
            Array.isArray(value) ? `${getCharEscape(value[0], escOpts)}-${getCharEscape(value[1], escOpts)}` : getCharEscape(value, escOpts)
          );
        });
      }
      return `${minStr}-${maxStr}${[...extraChars].join("")}`;
    },
    /**
    @param {CharacterSetNode} node
    */
    CharacterSet({ kind, negate, value, key }, state) {
      if (kind === "dot") {
        return state.currentFlags.dotAll ? state.appliedGlobalFlags.dotAll || state.useFlagMods ? "." : "[^]" : (
          // Onig's only line break char is line feed, unlike JS
          r`[^\n]`
        );
      }
      if (kind === "digit") {
        return negate ? r`\D` : r`\d`;
      }
      if (kind === "property") {
        if (state.useAppliedIgnoreCase && state.currentFlags.ignoreCase && UnicodePropertiesWithSpecificCase.has(value)) {
          throw new Error(`Unicode property "${value}" can't be case-insensitive when other chars have specific case`);
        }
        return `${negate ? r`\P` : r`\p`}{${key ? `${key}=` : ""}${value}}`;
      }
      if (kind === "word") {
        return negate ? r`\W` : r`\w`;
      }
      throw new Error(`Unexpected character set kind "${kind}"`);
    },
    /**
    @param {FlagsNode} node
    */
    Flags(node, state) {
      return (
        // The transformer should never turn on the properties for flags d, g, m since Onig doesn't
        // have equivs. Flag m is never used since Onig uses different line break chars than JS
        // (node.hasIndices ? 'd' : '') +
        // (node.global ? 'g' : '') +
        // (node.multiline ? 'm' : '') +
        (state.appliedGlobalFlags.ignoreCase ? "i" : "") + (node.dotAll ? "s" : "") + (node.sticky ? "y" : "")
      );
    },
    /**
    @param {GroupNode} node
    */
    Group({ atomic: atomic2, body, flags, parent }, state, gen) {
      const currentFlags = state.currentFlags;
      if (flags) {
        state.currentFlags = getNewCurrentFlags(currentFlags, flags);
      }
      const contents = body.map(gen).join("|");
      const result = !state.verbose && body.length === 1 && // Single alt
      parent.type !== "Quantifier" && !atomic2 && (!state.useFlagMods || !flags) ? contents : `(?${getGroupPrefix(atomic2, flags, state.useFlagMods)}${contents})`;
      state.currentFlags = currentFlags;
      return result;
    },
    /**
    @param {LookaroundAssertionNode} node
    */
    LookaroundAssertion({ body, kind, negate }, _, gen) {
      const prefix = `${kind === "lookahead" ? "" : "<"}${negate ? "!" : "="}`;
      return `(?${prefix}${body.map(gen).join("|")})`;
    },
    /**
    @param {QuantifierNode} node
    */
    Quantifier(node, _, gen) {
      return gen(node.body) + getQuantifierStr(node);
    },
    /**
    @param {SubroutineNode & {isRecursive: true}} node
    */
    Subroutine({ isRecursive, ref }, state) {
      if (!isRecursive) {
        throw new Error("Unexpected non-recursive subroutine in transformed AST");
      }
      const limit = state.recursionLimit;
      return ref === 0 ? `(?R=${limit})` : r`\g<${ref}&R=${limit}>`;
    }
  };
  var BaseEscapeChars = /* @__PURE__ */ new Set([
    "$",
    "(",
    ")",
    "*",
    "+",
    ".",
    "?",
    "[",
    "\\",
    "]",
    "^",
    "{",
    "|",
    "}"
  ]);
  var CharClassEscapeChars = /* @__PURE__ */ new Set([
    "-",
    "\\",
    "]",
    "^",
    // Literal `[` doesn't require escaping with flag u, but this can help work around regex source
    // linters and regex syntax processors that expect unescaped `[` to create a nested class
    "["
  ]);
  var CharClassEscapeCharsFlagV = /* @__PURE__ */ new Set([
    "(",
    ")",
    "-",
    "/",
    "[",
    "\\",
    "]",
    "^",
    "{",
    "|",
    "}",
    // Double punctuators; also includes already-listed `-` and `^`
    "!",
    "#",
    "$",
    "%",
    "&",
    "*",
    "+",
    ",",
    ".",
    ":",
    ";",
    "<",
    "=",
    ">",
    "?",
    "@",
    "`",
    "~"
  ]);
  var CharCodeEscapeMap = /* @__PURE__ */ new Map([
    [9, r`\t`],
    // horizontal tab
    [10, r`\n`],
    // line feed
    [11, r`\v`],
    // vertical tab
    [12, r`\f`],
    // form feed
    [13, r`\r`],
    // carriage return
    [8232, r`\u2028`],
    // line separator
    [8233, r`\u2029`],
    // paragraph separator
    [65279, r`\uFEFF`]
    // ZWNBSP/BOM
  ]);
  var casedRe = /^\p{Cased}$/u;
  function charHasCase(char) {
    return casedRe.test(char);
  }
  function getCasesOutsideCharClassRange(node, options) {
    const firstOnly = !!options?.firstOnly;
    const min = node.min.value;
    const max = node.max.value;
    const found = [];
    if (min < 65 && (max === 65535 || max >= 131071) || min === 65536 && max >= 131071) {
      return found;
    }
    for (let i = min; i <= max; i++) {
      const char = cp(i);
      if (!charHasCase(char)) {
        continue;
      }
      const charsOutsideRange = getIgnoreCaseMatchChars(char).filter((caseOfChar) => {
        const num = caseOfChar.codePointAt(0);
        return num < min || num > max;
      });
      if (charsOutsideRange.length) {
        found.push(...charsOutsideRange);
        if (firstOnly) {
          break;
        }
      }
    }
    return found;
  }
  function getCharEscape(codePoint, { escDigit, inCharClass, useFlagV }) {
    if (CharCodeEscapeMap.has(codePoint)) {
      return CharCodeEscapeMap.get(codePoint);
    }
    if (
      // Control chars, etc.; condition modeled on the Chrome developer console's display for strings
      codePoint < 32 || codePoint > 126 && codePoint < 160 || // Unicode planes 4-16; unassigned, special purpose, and private use area
      codePoint > 262143 || // Avoid corrupting a preceding backref by immediately following it with a literal digit
      escDigit && isDigitCharCode(codePoint)
    ) {
      return codePoint > 255 ? `\\u{${codePoint.toString(16).toUpperCase()}}` : `\\x${codePoint.toString(16).toUpperCase().padStart(2, "0")}`;
    }
    const escapeChars = inCharClass ? useFlagV ? CharClassEscapeCharsFlagV : CharClassEscapeChars : BaseEscapeChars;
    const char = cp(codePoint);
    return (escapeChars.has(char) ? "\\" : "") + char;
  }
  function getCodePointRangesFromChars(chars) {
    const codePoints = chars.map((char) => char.codePointAt(0)).sort((a, b) => a - b);
    const values = [];
    let start = null;
    for (let i = 0; i < codePoints.length; i++) {
      if (codePoints[i + 1] === codePoints[i] + 1) {
        start ??= codePoints[i];
      } else if (start === null) {
        values.push(codePoints[i]);
      } else {
        values.push([start, codePoints[i]]);
        start = null;
      }
    }
    return values;
  }
  function getGroupPrefix(atomic2, flagMods, useFlagMods) {
    if (atomic2) {
      return ">";
    }
    let mods = "";
    if (flagMods && useFlagMods) {
      const { enable, disable } = flagMods;
      mods = (enable?.ignoreCase ? "i" : "") + (enable?.dotAll ? "s" : "") + (disable ? "-" : "") + (disable?.ignoreCase ? "i" : "") + (disable?.dotAll ? "s" : "");
    }
    return `${mods}:`;
  }
  function getQuantifierStr({ kind, max, min }) {
    let base;
    if (!min && max === 1) {
      base = "?";
    } else if (!min && max === Infinity) {
      base = "*";
    } else if (min === 1 && max === Infinity) {
      base = "+";
    } else if (min === max) {
      base = `{${min}}`;
    } else {
      base = `{${min},${max === Infinity ? "" : max}}`;
    }
    return base + {
      greedy: "",
      lazy: "?",
      possessive: "+"
    }[kind];
  }
  function isAnyGroup({ type }) {
    return type === "CapturingGroup" || type === "Group" || type === "LookaroundAssertion";
  }
  function isDigitCharCode(value) {
    return value > 47 && value < 58;
  }
  function isLiteralHyphen({ type, value }) {
    return type === "Character" && value === 45;
  }

  // src/subclass.js
  var EmulatedRegExp = class _EmulatedRegExp extends RegExp {
    /**
    @type {Map<number, {
      hidden?: true;
      transferTo?: number;
    }>}
    */
    #captureMap = /* @__PURE__ */ new Map();
    /**
    @type {RegExp | EmulatedRegExp | null}
    */
    #compiled = null;
    /**
    @type {string}
    */
    #pattern;
    /**
    @type {Map<number, string>?}
    */
    #nameMap = null;
    /**
    @type {string?}
    */
    #strategy = null;
    /**
    Can be used to serialize the instance.
    @type {EmulatedRegExpOptions}
    */
    rawOptions = {};
    // Override the getter with one that works with lazy-compiled regexes
    get source() {
      return this.#pattern || "(?:)";
    }
    /**
    @overload
    @param {string} pattern
    @param {string} [flags]
    @param {EmulatedRegExpOptions} [options]
    */
    /**
    @overload
    @param {EmulatedRegExp} pattern
    @param {string} [flags]
    */
    constructor(pattern, flags, options) {
      const lazyCompile = !!options?.lazyCompile;
      if (pattern instanceof RegExp) {
        if (options) {
          throw new Error("Cannot provide options when copying a regexp");
        }
        const re = pattern;
        super(re, flags);
        this.#pattern = re.source;
        if (re instanceof _EmulatedRegExp) {
          this.#captureMap = re.#captureMap;
          this.#nameMap = re.#nameMap;
          this.#strategy = re.#strategy;
          this.rawOptions = re.rawOptions;
        }
      } else {
        const opts = {
          hiddenCaptures: [],
          strategy: null,
          transfers: [],
          ...options
        };
        super(lazyCompile ? "" : pattern, flags);
        this.#pattern = pattern;
        this.#captureMap = createCaptureMap(opts.hiddenCaptures, opts.transfers);
        this.#strategy = opts.strategy;
        this.rawOptions = options ?? {};
      }
      if (!lazyCompile) {
        this.#compiled = this;
      }
    }
    /**
    Called internally by all String/RegExp methods that use regexes.
    @override
    @param {string} str
    @returns {RegExpExecArray?}
    */
    exec(str) {
      if (!this.#compiled) {
        const { lazyCompile, ...rest } = this.rawOptions;
        this.#compiled = new _EmulatedRegExp(this.#pattern, this.flags, rest);
      }
      const useLastIndex = this.global || this.sticky;
      const pos = this.lastIndex;
      if (this.#strategy === "clip_search" && useLastIndex && pos) {
        this.lastIndex = 0;
        const match = this.#execCore(str.slice(pos));
        if (match) {
          adjustMatchDetailsForOffset(match, pos, str, this.hasIndices);
          this.lastIndex += pos;
        }
        return match;
      }
      return this.#execCore(str);
    }
    /**
    Adds support for hidden and transfer captures.
    @param {string} str
    @returns
    */
    #execCore(str) {
      this.#compiled.lastIndex = this.lastIndex;
      const match = super.exec.call(this.#compiled, str);
      this.lastIndex = this.#compiled.lastIndex;
      if (!match || !this.#captureMap.size) {
        return match;
      }
      const matchCopy = [...match];
      match.length = 1;
      let indicesCopy;
      if (this.hasIndices) {
        indicesCopy = [...match.indices];
        match.indices.length = 1;
      }
      const mappedNums = [0];
      for (let i = 1; i < matchCopy.length; i++) {
        const { hidden, transferTo } = this.#captureMap.get(i) ?? {};
        if (hidden) {
          mappedNums.push(null);
        } else {
          mappedNums.push(match.length);
          match.push(matchCopy[i]);
          if (this.hasIndices) {
            match.indices.push(indicesCopy[i]);
          }
        }
        if (transferTo && matchCopy[i] !== void 0) {
          const to = mappedNums[transferTo];
          if (!to) {
            throw new Error(`Invalid capture transfer to "${to}"`);
          }
          match[to] = matchCopy[i];
          if (this.hasIndices) {
            match.indices[to] = indicesCopy[i];
          }
          if (match.groups) {
            if (!this.#nameMap) {
              this.#nameMap = createNameMap(this.source);
            }
            const name = this.#nameMap.get(transferTo);
            if (name) {
              match.groups[name] = matchCopy[i];
              if (this.hasIndices) {
                match.indices.groups[name] = indicesCopy[i];
              }
            }
          }
        }
      }
      return match;
    }
  };
  function adjustMatchDetailsForOffset(match, offset, input, hasIndices) {
    match.index += offset;
    match.input = input;
    if (hasIndices) {
      const indices = match.indices;
      for (let i = 0; i < indices.length; i++) {
        const arr = indices[i];
        if (arr) {
          indices[i] = [arr[0] + offset, arr[1] + offset];
        }
      }
      const groupIndices = indices.groups;
      if (groupIndices) {
        Object.keys(groupIndices).forEach((key) => {
          const arr = groupIndices[key];
          if (arr) {
            groupIndices[key] = [arr[0] + offset, arr[1] + offset];
          }
        });
      }
    }
  }
  function createCaptureMap(hiddenCaptures, transfers) {
    const captureMap = /* @__PURE__ */ new Map();
    for (const num of hiddenCaptures) {
      captureMap.set(num, {
        hidden: true
      });
    }
    for (const [to, from] of transfers) {
      for (const num of from) {
        getOrInsert(captureMap, num, {}).transferTo = to;
      }
    }
    return captureMap;
  }
  function createNameMap(pattern) {
    const re = /(?<capture>\((?:\?<(?![=!])(?<name>[^>]+)>|(?!\?)))|\\?./gsu;
    const map = /* @__PURE__ */ new Map();
    let numCharClassesOpen = 0;
    let numCaptures = 0;
    let match;
    while (match = re.exec(pattern)) {
      const { 0: m, groups: { capture, name } } = match;
      if (m === "[") {
        numCharClassesOpen++;
      } else if (!numCharClassesOpen) {
        if (capture) {
          numCaptures++;
          if (name) {
            map.set(numCaptures, name);
          }
        }
      } else if (m === "]") {
        numCharClassesOpen--;
      }
    }
    return map;
  }
  function toRegExp(pattern, options) {
    const d = toRegExpDetails(pattern, options);
    if (d.options) {
      return new EmulatedRegExp(d.pattern, d.flags, d.options);
    }
    return new RegExp(d.pattern, d.flags);
  }
  function toRegExpDetails(pattern, options) {
    const opts = getOptions(options);
    const onigurumaAst = J(pattern, {
      flags: opts.flags,
      normalizeUnknownPropertyNames: true,
      rules: {
        captureGroup: opts.rules.captureGroup,
        singleline: opts.rules.singleline
      },
      skipBackrefValidation: opts.rules.allowOrphanBackrefs,
      unicodePropertyMap: JsUnicodePropertyMap
    });
    const regexPlusAst = transform(onigurumaAst, {
      accuracy: opts.accuracy,
      asciiWordBoundaries: opts.rules.asciiWordBoundaries,
      avoidSubclass: opts.avoidSubclass,
      bestEffortTarget: opts.target
    });
    const generated = generate(regexPlusAst, opts);
    const recursionResult = recursion(generated.pattern, {
      captureTransfers: generated._captureTransfers,
      hiddenCaptures: generated._hiddenCaptures,
      mode: "external"
    });
    const possessiveResult = possessive(recursionResult.pattern);
    const atomicResult = atomic(possessiveResult.pattern, {
      captureTransfers: recursionResult.captureTransfers,
      hiddenCaptures: recursionResult.hiddenCaptures
    });
    const details = {
      pattern: atomicResult.pattern,
      flags: `${opts.hasIndices ? "d" : ""}${opts.global ? "g" : ""}${generated.flags}${generated.options.disable.v ? "u" : "v"}`
    };
    if (opts.avoidSubclass) {
      if (opts.lazyCompileLength !== Infinity) {
        throw new Error("Lazy compilation requires subclass");
      }
    } else {
      const hiddenCaptures = atomicResult.hiddenCaptures.sort((a, b) => a - b);
      const transfers = Array.from(atomicResult.captureTransfers);
      const strategy = regexPlusAst._strategy;
      const lazyCompile = details.pattern.length >= opts.lazyCompileLength;
      if (hiddenCaptures.length || transfers.length || strategy || lazyCompile) {
        details.options = {
          ...hiddenCaptures.length && { hiddenCaptures },
          ...transfers.length && { transfers },
          ...strategy && { strategy },
          ...lazyCompile && { lazyCompile }
        };
      }
    }
    return details;
  }

  /**
   * Regex engine wrapper around oniguruma-to-es
   * Converts Oniguruma/PCRE2 patterns to native JavaScript RegExp
   */
  class RegexEngine {
    constructor(lexerDef = null) {
      this.cache = new Map();
      this.lexerDef = lexerDef;
    }

    /**
     * Compile a pattern with flags
     * @param {string} pattern - Oniguruma/PCRE2 pattern
     * @param {string} flags - Pattern flags (m, i, s, etc.)
     * @param {boolean} caseInsensitive - Whether to make the pattern case-insensitive
     * @returns {RegExp} Compiled regular expression
     */
    compile(pattern, flags = '', caseInsensitive = false) {
      const cacheKey = `${pattern}::${flags}::${caseInsensitive}`;

      if (this.cache.has(cacheKey)) {
        return this.cache.get(cacheKey);
      }

      const regex = this.createRegex(pattern, flags, caseInsensitive);
      this.cache.set(cacheKey, regex);
      return regex;
    }

    /**
     * Transform PCRE2 pattern to be compatible with oniguruma-to-es
     * @param {string} pattern - PCRE2 pattern
     * @returns {string} Transformed pattern
     */
    transformPattern(pattern) {
      // The Rust lexer has pattern "#![ ^[ \r\n ].*$" where \r and \n are literal
      // backslash+r and backslash+n (two characters each, not escape sequences).
      // This pattern can't be parsed by oniguruma-to-es due to the [^[] sequence.
      // The [ exclusion in [^[ is redundant since #! already doesn't match #[foo].
      // We remove the [ from the character class to make it compatible.

      // Construct the pattern using character codes to match the literal backslashes
      const rustShebangPattern = String.fromCharCode(35, 33, 91, 94, 91, 92, 114, 92, 110, 93, 46, 42, 36); // #![ ^[ \r\n ].*$
      const transformedRustPattern = String.fromCharCode(35, 33, 91, 94, 92, 114, 92, 110, 93, 46, 42, 36); // #![ ^\r\n].*$

      if (pattern === rustShebangPattern) {
        return transformedRustPattern;
      }

      // The Python lexer has patterns where [] is used to match literal ] and [
      // In PCRE2, [] at the start or end of a character class matches a literal ]
      // JavaScript doesn't allow empty character classes, so we need to transform these.
      // Pattern examples: []{}:(),;[]  [])}]  [{([]
      // NOTE: These transformations must happen BEFORE oniguruma-to-es processing
      if (pattern === '[]{}:(),;[]') {
        return '[\\]{}:(),;\\[]';  // Python punctuation
      }
      if (pattern === '[{([]') {
        return '[\\{\\[\\(]';  // Python nested braces
      }
      if (pattern === '[])}]') {
        return pattern;  // Handled correctly by oniguruma-to-es
      }
      // Haskell has similar patterns
      // For PCRE2 patterns like [][]][(),;{}],
      // we need to convert to JavaScript-compatible character class
      if (pattern === '[][(),;`{}]') {
        // The pattern is a character class matching: ], (, ), ,, ;, `, {, }
        // In JavaScript, use \x5d (hex code for ]) to avoid issues
        return '[\\x5d(),;`{}]';  // Haskell punctuation
      }
      if (pattern === '[][\p{Lu}@^_]') {
        // The pattern is a character class matching: ], \p{Lu}, @, ^, _
        return '[\\x5d\\p{Lu}@^_]';  // Haskell symbols
      }

      return pattern;
    }

    /**
     * Create RegExp from Oniguruma pattern
     * @param {string} pattern - Oniguruma/PCRE2 pattern
     * @param {string} flags - Pattern flags
     * @param {boolean} caseInsensitive - Whether to make the pattern case-insensitive
     * @returns {RegExp} JavaScript RegExp object
     */
    createRegex(pattern, flags, caseInsensitive = false) {
      // Transform PCRE2 pattern for compatibility (do this outside try block for error logging)
      let cleanPattern = this.transformPattern(pattern);

      try {
        // Parse flags
        const options = {
          global: false, // We don't want global matching by default
          forgiving: true, // Be lenient with unsupported features
          recursionLimit: 10, // Aggressively limit recursion to prevent catastrophic backtracking
          lazyCompileLength: 1, // Lazy compile very short patterns
        };

        // Handle flag modifiers in pattern
        // Oniguruma uses (?i), (?m), (?s), (?x), (?is), (?sx), etc. inline modifiers
        // JavaScript doesn't support inline flags, so we extract them and add to RegExp flags
        let jsFlags = '';
        let hasFreeSpacing = false;

        // Check for inline flag modifiers - can be combined like (?is), (?sx), etc.
        // Match (? followed by any combination of letters i, m, s, x, etc.
        const flagRegex = /\(\?([a-z]+)\)/gi;
        let match;
        while ((match = flagRegex.exec(cleanPattern)) !== null) {
          const flags = match[1].toLowerCase();
          for (const flag of flags) {
            if (flag === 'i' && !jsFlags.includes('i')) {
              jsFlags += 'i'; // Case insensitive
            } else if (flag === 'm' && !jsFlags.includes('m')) {
              jsFlags += 'm'; // Multiline
            } else if (flag === 's' && !jsFlags.includes('s')) {
              jsFlags += 's'; // DotAll (single-line mode - . matches newlines)
            } else if (flag === 'x' && !jsFlags.includes('x')) {
              // Free-spacing mode - ignores whitespace and allows comments
              // JavaScript doesn't natively support this, so we preprocess the pattern
              hasFreeSpacing = true;
              jsFlags += 'x';
            }
          }
        }

        // Remove all flag modifiers from the pattern
        cleanPattern = cleanPattern.replace(/\(\?[a-z]+\)/gi, '');

        // Decode HTML entities in the pattern
        // XML parsers encode characters like newlines as &#xA; or &#10;
        // We need to decode them before compiling the regex
        cleanPattern = cleanPattern.replace(/&#x([0-9a-fA-F]+);/g, (match, hex) => {
          return String.fromCharCode(parseInt(hex, 16));
        });
        cleanPattern = cleanPattern.replace(/&#(\d+);/g, (match, dec) => {
          return String.fromCharCode(parseInt(dec, 10));
        });

        // Decode named HTML entities
        const htmlEntities = {
          'lt': '<',
          'gt': '>',
          'amp': '&',
          'quot': '"',
          'apos': '\''
        };
        cleanPattern = cleanPattern.replace(/&(lt|gt|amp|quot|apos);/g, (match, entity) => {
          return htmlEntities[entity] || match;
        });

        // If free-spacing mode is enabled, manually preprocess the pattern
        // oniguruma-to-es doesn't support the x flag, so we handle it ourselves
        if (hasFreeSpacing) {
          // Process line by line to handle comments correctly
          const lines = cleanPattern.split('\n');
          const processedLines = [];

          for (let line of lines) {
            // Find the comment position (first # not inside a character class or escaped)
            let commentPos = -1;
            let inCharClass = false;
            let inEscape = false;

            for (let i = 0; i < line.length; i++) {
              const char = line[i];

              if (inEscape) {
                inEscape = false;
                continue;
              }

              if (char === '\\') {
                inEscape = true;
                continue;
              }

              if (char === '[') {
                inCharClass = true;
                continue;
              }

              if (char === ']') {
                inCharClass = false;
                continue;
              }

              // If we're not in a character class and we see #, that starts a comment
              if (!inCharClass && char === '#') {
                commentPos = i;
                break;
              }
            }

            // Remove the comment and trailing whitespace
            if (commentPos >= 0) {
              line = line.substring(0, commentPos);
            }

            // Remove leading/trailing whitespace
            line = line.trim();

            // Only add non-empty lines
            if (line.length > 0) {
              processedLines.push(line);
            }
          }

          // Join the lines (free-spacing mode removes all whitespace)
          cleanPattern = processedLines.join('');
        }

        // Also check explicit flags passed as parameter
        if ((flags.includes('i') || caseInsensitive) && !jsFlags.includes('i')) {
          jsFlags += 'i';
        }
        if (flags.includes('m') && !jsFlags.includes('m')) {
          jsFlags += 'm';
        }
        if (flags.includes('s') && !jsFlags.includes('s')) {
          jsFlags += 's';
        }

        // Check if lexer has dotAll enabled (makes . match newlines)
        if (this.lexerDef && this.lexerDef.dotAll && !jsFlags.includes('s')) {
          jsFlags += 's';
        }

        // Convert to JavaScript RegExp using oniguruma-to-es
        const regex = toRegExp(cleanPattern, options);

        // Use the regex from oniguruma-to-es directly (it has 'v' flag for Unicode)
        // Just add our custom flags (i, m, s) if not already present
        let finalFlags = regex.flags;
        if (jsFlags.includes('i') && !finalFlags.includes('i')) {
          finalFlags += 'i';
        }
        if (jsFlags.includes('m') && !finalFlags.includes('m')) {
          finalFlags += 'm';
        }
        if (jsFlags.includes('s') && !finalFlags.includes('s')) {
          finalFlags += 's';
        }

        // oniguruma-to-es transforms . to [^\n] when (?s) is not present
        // If we're adding the s flag (dotAll mode), we need to revert this
        // transformation so that . matches newlines as intended
        let finalSource = regex.source;

        // Decode HTML entities in the regex source
        // oniguruma-to-es encodes characters like <, >, and & as HTML entities
        // We need to decode them back to actual characters for the regex to work
        finalSource = finalSource.replace(/&lt;/g, '<');
        finalSource = finalSource.replace(/&gt;/g, '>');
        finalSource = finalSource.replace(/&amp;/g, '&');

        if (finalFlags.includes('s')) {
          // Replace [^\n] with . so dotAll mode works correctly
          // This reverses the common case where . was transformed to [^\n]
          // The source contains literal backslash-n, so we need \\n in the regex
          finalSource = finalSource.replace(/\[\^\\n\]/g, '.');
        }

        return new RegExp(finalSource, finalFlags);
      } catch (error) {
        throw new Error(`Failed to compile pattern "${pattern}": ${error.message}`);
      }
    }

    /**
     * Execute regex and return match result
     * @param {RegExp} regex - Compiled regex
     * @param {string} text - Text to match against
     * @param {number} startOffset - Starting position in text
     * @returns {Match|null} Match result or null if no match
     */
    match(regex, text, startOffset = 0) {
      // Use sticky flag with lastIndex to match at specific position
      // This preserves ^ and \b anchors correctly
      const stickyRegex = new RegExp(regex.source, regex.flags + 'y');
      stickyRegex.lastIndex = startOffset;

      const result = stickyRegex.exec(text);

      if (!result) {
        return null;
      }

      return result;
    }

    /**
     * Clear the pattern cache
     */
    clearCache() {
      this.cache.clear();
    }
  }

  /**
   * State Matcher - Core tokenization engine
   * Implements the state machine that matches patterns and executes actions
   */
  class StateMatcher {
    constructor(lexerDef) {
      this.lexerDef = lexerDef;
      this.regexEngine = new RegexEngine(lexerDef);
      this.compiledRules = new Map();
    }

    /**
     * Tokenize text starting from a given state (async generator-based)
     * Matches Crystal's deque-based approach
     * @param {string} text - Text to tokenize
     * @param {string} initialState - Starting state name
     * @yields {Object} Individual tokens
     */
    async *tokenize(text, initialState = 'root') {
      const stateStack = [initialState];
      let position = 0;
      const deque = []; // Buffer for tokens

      // Track iterations to prevent infinite loops
      let iterations = 0;
      const maxIterations = text.length * 100; // Safety limit

      while (true) {
        // If deque has tokens, return one (like Crystal's @dq.shift)
        if (deque.length > 0) {
          yield deque.shift();
          continue;
        }

        // If we've reached end of text, we're done
        if (position >= text.length) {
          break;
        }

        // Prevent infinite loops
        iterations++;
        if (iterations > maxIterations) {
          console.error('Infinite loop detected in tokenization');
          break;
        }

        const currentState = stateStack[stateStack.length - 1];
        const stateDef = this.lexerDef.states[currentState];

        if (!stateDef) {
          // No matching state - advance one character
          position++;
          continue;
        }

        // Try to match a rule
        const matchResult = this.findMatch(stateDef, text, position);

        if (!matchResult) {
          // No rule matches at current position
          // Create one error token and add to deque (like Crystal)
          const char = text[position];
          if (char.charCodeAt(0) === 10) { // newline
            deque.push({ type: 'Text', value: '\n' });
            stateStack.length = 0;
            stateStack.push('root');
          } else {
            deque.push({ type: 'Error', value: char });
          }
          position++;
          // Continue to next iteration to return from deque
          continue;
        }

        // A rule matched!
        const { match, rule } = matchResult;

        // Only execute token actions if the match has non-zero length
        // Zero-length matches (like lookaheads) should not generate tokens
        const matchLength = match[0].length || 0;
        if (matchLength > 0) {
          // Execute actions and add all tokens to deque
          const newTokens = await this.executeActions(rule.actions, match, stateStack, position);

          // Split tokens containing newlines (like Crystal's split_tokens)
          const splitTokens = this.splitTokens(newTokens);
          for (const token of splitTokens) {
            deque.push(token);
          }

          // Advance position by match length
          position += matchLength;
        } else {
          // For zero-length matches, only execute non-token actions (push, pop, include)
          // Do NOT advance position - continue to next rule
          this.executeActionsNonToken(rule.actions, match, stateStack, position);
        }
        // Continue to next iteration to return from deque
      }
    }

    /**
     * Execute actions and return array of tokens
     * @param {Array} actions - Actions to execute
     * @param {Array} match - Regex match result
     * @param {Array} stateStack - State stack
     * @param {number} position - Current position
     * @returns {Promise<Array>} Array of tokens
     */
    async executeActions(actions, match, stateStack, position) {
      const tokens = [];
      for (const action of actions) {
        await this.executeAction(action, match, stateStack, tokens, position);
      }
      return tokens;
    }

    /**
     * Execute non-token actions (push, pop, include) for zero-length matches
     * @param {Array} actions - Actions to execute
     * @param {Array} match - Regex match result
     * @param {Array} stateStack - State stack
     * @param {number} position - Current position
     */
    async executeActionsNonToken(actions, match, stateStack, position) {
      for (const action of actions) {
        // Only execute state-modifying actions, not token-generating actions
        if (action.type === 'push' || action.type === 'pop' || action.type === 'include') {
          await this.executeAction(action, match, stateStack, [], position);
        }
      }
    }

    /**
     * If a token contains a newline, split it into two tokens
     * @param {Array} tokens - Array of tokens
     * @returns {Array} Tokens with newlines split
     */
    splitTokens(tokens) {
      const splitTokens = [];
      for (const token of tokens) {
        if (token.value.includes('\n')) {
          const values = token.value.split('\n');
          for (let i = 0; i < values.length; i++) {
            let value = values[i];
            // Add back the newline except for the last value
            if (i < values.length - 1) {
              value += '\n';
            }
            splitTokens.push({ type: token.type, value });
          }
        } else {
          splitTokens.push(token);
        }
      }
      return splitTokens;
    }

    /**
     * Collapse consecutive tokens of the same type
     * @param {Array} tokens - Array of tokens
     * @returns {Array} Collapsed tokens
     */
    collapseTokens(tokens) {
      if (tokens.length === 0) return [];

      const collapsed = [];
      let current = { ...tokens[0] };

      for (let i = 1; i < tokens.length; i++) {
        const token = tokens[i];

        if (token.type === current.type) {
          // Merge with current token
          current.value += token.value;
        } else {
          // Push current and start new
          collapsed.push(current);
          current = { ...token };
        }
      }

      // Push the last token
      collapsed.push(current);

      return collapsed;
    }

    /**
     * Find a matching rule at the current position
     * @param {Object} stateDef - State definition
     * @param {string} text - Text to search
     * @param {number} position - Current position
     * @returns {Object|null} Match result or null
     */
    findMatch(stateDef, text, position) {
      const rules = this.getCompiledRules(stateDef.name);

      for (const rule of rules) {
        // If regex is null, this is a zero-length match rule
        if (rule.regex === null) {
          return {
            match: [''], // Zero-length match
            rule
          };
        }

        const regex = rule.regex;
        const match = this.regexEngine.match(regex, text, position);

        if (match && match.index === position) {
          return { match, rule };
        }
      }

      return null;
    }

    /**
     * Get or compile rules for a state
     * @param {string} stateName - State name
     * @returns {Array} Compiled rules
     */
    getCompiledRules(stateName) {
      if (this.compiledRules.has(stateName)) {
        return this.compiledRules.get(stateName);
      }

      const stateDef = this.lexerDef.states[stateName];
      if (!stateDef) {
        return [];
      }

      // Expand rules with includes
      const compiled = this.expandRules(stateDef.rules, new Set());

      this.compiledRules.set(stateName, compiled);
      return compiled;
    }

    /**
     * Expand rules, resolving includes recursively
     * @param {Array} rules - Rules to expand
     * @param {Set} visited - States already visited (to prevent infinite recursion)
     * @returns {Array} Expanded compiled rules
     */
    expandRules(rules, visited) {
      const expanded = [];

      for (const rule of rules) {
        // First, process any include actions in this rule
        const includeActions = rule.actions.filter(a => a.type === 'include');
        const nonIncludeActions = rule.actions.filter(a => a.type !== 'include');

        // If there's a pattern and non-include actions, compile and add the rule FIRST
        // Rules defined in the current state take priority over included states
        if (nonIncludeActions.length > 0) {
          expanded.push({
            regex: rule.pattern ? this.regexEngine.compile(rule.pattern, '', this.lexerDef.caseInsensitive) : null,
            actions: rule.actions,
          });
        }

        // THEN expand includes from referenced states
        // These will be checked after the current state's rules
        for (const includeAction of includeActions) {
          const includedState = this.lexerDef.states[includeAction.state];
          if (includedState) {
            // Prevent infinite recursion
            if (!visited.has(includeAction.state)) {
              visited.add(includeAction.state);
              const includedRules = this.expandRules(includedState.rules, visited);
              expanded.push(...includedRules);
            }
          }
        }
      }

      return expanded;
    }

    /**
     * Execute an action
     * @param {Object} action - Action definition
     * @param {Array} match - Regex match result
     * @param {Array} stateStack - State stack
     * @param {Array} tokens - Token array
     * @param {number} position - Current position
     */
    async executeAction(action, match, stateStack, tokens, position) {
      switch (action.type) {
        case 'token':
          tokens.push({
            type: action.tokenType,
            value: match[0],
          });
          break;

        case 'bygroups':
          // Create one token per capture group
          // match[0] is the full match, match[1] is first group, etc.
          for (let i = 0; i < action.groups.length; i++) {
            const groupAction = action.groups[i];
            const groupIndex = i + 1; // match[0] is full match, groups start at 1

            if (groupIndex < match.length && match[groupIndex] !== undefined) {
              // Skip empty groups (e.g., optional whitespace that didn't match)
              if (match[groupIndex] !== '') {
                // If groupAction is usingself, recursively tokenize the matched text
                if (groupAction.type === 'usingself') {
                  // Consume the async generator and collect tokens
                  const recursiveTokens = [];
                  for await (const token of this.tokenize(match[groupIndex], groupAction.state)) {
                    recursiveTokens.push(token);
                  }
                  tokens.push(...recursiveTokens);
                } else if (groupAction.type === 'using') {
                  // Shunt to another lexer
                  // Normalize lexer name to lowercase
                  const lexer = new Lexer(groupAction.lexer.toLowerCase());
                  await lexer.init();
                  const usingTokens = await lexer.tokenize(match[groupIndex]);
                  tokens.push(...usingTokens);
                } else if (groupAction.type === 'usingbygroup') {
                  // Shunt to a lexer specified by a capture group
                  // Get the lexer name from the specified capture group
                  const lexerName = match[groupAction.lexerIndex];
                  if (lexerName) {
                    // Get the content by concatenating the specified capture groups
                    const content = groupAction.contentIndex.map(idx => match[idx] || '').join('');

                    if (content) {
                      try {
                        // Normalize lexer name to lowercase
                        const lexer = new Lexer(String(lexerName).toLowerCase());
                        await lexer.init();
                        const usingTokens = await lexer.tokenize(content);
                        tokens.push(...usingTokens);
                      } catch (error) {
                        // Fallback to 'text' lexer if the specified lexer is not found
                        console.warn(`Lexer '${lexerName}' not found, falling back to 'text'`);
                        const textLexer = new Lexer('text');
                        await textLexer.init();
                        const textTokens = await textLexer.tokenize(content);
                        tokens.push(...textTokens);
                      }
                    }
                  }
                } else if (groupAction.type === 'token') {
                  tokens.push({
                    type: groupAction.tokenType,
                    value: match[groupIndex],
                  });
                }
              }
            }
          }
          break;

        case 'push':
          // Push state(s) onto stack
          // Can have multiple states to push in sequence
          // If no state specified (null or empty), push the current state again (for nested structures)
          const statesToPush = action.states || (action.state ? [action.state] : []);

          if (statesToPush.length === 0) {
            // <push/> without state means push current state
            stateStack.push(stateStack[stateStack.length - 1]);
          } else {
            // Push each state in sequence
            for (const state of statesToPush) {
              if (state === '#pop' && stateStack.length > 1) {
                // #pop means pop the state instead of pushing
                stateStack.pop();
              } else {
                stateStack.push(state);
              }
            }
          }
          break;

        case 'pop':
          // Pop specified number of states from stack
          const depth = action.depth || 1;
          const toPop = Math.min(depth, stateStack.length - 1);
          for (let i = 0; i < toPop; i++) {
            stateStack.pop();
          }
          break;

        case 'include':
          // Include is handled during rule compilation
          // No action needed here
          break;

        case 'using': {
          // Shunt to another lexer entirely
          // Create a new lexer and tokenize the matched text with it
          // Normalize lexer name to lowercase
          const lexer = new Lexer(action.lexer.toLowerCase());
          await lexer.init();

          // Tokenize the matched text with the new lexer
          const usingTokens = await lexer.tokenize(match[0]);

          // Add all tokens from the other lexer to our token array
          tokens.push(...usingTokens);
          break;
        }

        case 'combined': {
          // Combine multiple states into one anonymous state
          // Merge rules from all specified states
          const mergedRules = [];
          for (const stateName of action.states) {
            const stateDef = this.lexerDef.states[stateName];
            if (stateDef && stateDef.rules) {
              mergedRules.push(...stateDef.rules);
            }
          }

          // Create anonymous state with a unique name
          const anonymousStateName = `__combined_${Date.now()}_${Math.random().toString(36).substring(2, 10)}__`;

          // Add the new state to the lexer definition
          this.lexerDef.states[anonymousStateName] = {
            name: anonymousStateName,
            rules: mergedRules,
          };

          // Push the anonymous state onto the stack
          stateStack.push(anonymousStateName);
          break;
        }

        default:
          console.warn('Unknown action type:', action.type);
      }
    }
  }

  /**
   * Main Lexer class - Public API for tokenizing text
   */
  class Lexer {
    constructor(lexerName) {
      this.lexerName = lexerName;
      this.lexerDef = null;
      this.initialized = false;
    }

    /**
     * Initialize the lexer (lazy loading)
     * @returns {Promise<void>}
     */
    async init() {
      if (this.initialized) {
        return;
      }

      this.lexerDef = await loadLexer(this.lexerName);
      this.initialized = true;
    }

    /**
     * Tokenize text
     * @param {string} text - Text to tokenize
     * @param {Object} options - Options
     * @param {string} options.state - Initial state (default: 'root')
     * @returns {Promise<Array>} Array of tokens
     */
    async tokenize(text, options = {}) {
      await this.init();

      // Respect the `ensure_nl` config option
      // If text doesn't end with newline and ensure_nl is true, append one
      let textToTokenize = text;
      if (this.lexerDef.ensureNl && textToTokenize.length > 0 && textToTokenize[textToTokenize.length - 1] !== '\n') {
        textToTokenize = textToTokenize + '\n';
      }

      // Tartrazine always starts in 'root' state
      const initialState = options.state || 'root';
      const matcher = new StateMatcher(this.lexerDef);

      // Collect all tokens from the async generator
      const tokens = [];
      for await (const token of matcher.tokenize(textToTokenize, initialState)) {
        tokens.push(token);
      }

      // Collapse consecutive tokens of the same type
      return matcher.collapseTokens(tokens);
    }

    /**
     * Get lexer metadata
     * @returns {Promise<Object>} Lexer metadata
     */
    async getMetadata() {
      await this.init();
      return {
        name: this.lexerDef.name,
        aliases: this.lexerDef.aliases,
        filenames: this.lexerDef.filenames,
        mimeTypes: this.lexerDef.mimeTypes,
      };
    }
  }

  /**
   * Token type to CSS abbreviation mapping
   * Maps Pygments token types to short CSS class names
   */
  const TokenAbbreviations = {
    "Background": "b",
    "CodeLine": "cl",
    "Comment": "c",
    "CommentHashbang": "ch",
    "CommentMultiline": "cm",
    "CommentPreproc": "cp",
    "CommentPreprocFile": "cpf",
    "CommentSingle": "cs",
    "CommentSpecial": "cs",
    "Error": "e",
    "Generic": "g",
    "GenericDeleted": "gd",
    "GenericEmph": "ge",
    "GenericError": "gr",
    "GenericHeading": "gh",
    "GenericInserted": "gi",
    "GenericOutput": "go",
    "GenericPrompt": "gp",
    "GenericStrong": "gs",
    "GenericSubheading": "gu",
    "GenericTraceback": "gt",
    "GenericUnderline": "gl",
    "Highlight": "hl",
    "Keyword": "k",
    "KeywordConstant": "kc",
    "KeywordDeclaration": "kd",
    "KeywordNamespace": "kn",
    "KeywordPseudo": "kp",
    "KeywordReserved": "kr",
    "KeywordType": "kt",
    "LineHighlight": "lh",
    "LineNumbers": "ln",
    "LineNumbersTable": "lnt",
    "LineTable": "lt",
    "LineTableTD": "lttd",
    "Literal": "l",
    "LiteralDate": "ld",
    "LiteralNumber": "m",
    "LiteralNumberBin": "lnb",
    "LiteralNumberFloat": "lnf",
    "LiteralNumberHex": "lnh",
    "LiteralNumberInteger": "lni",
    "LiteralNumberIntegerLong": "lnil",
    "LiteralNumberOct": "lno",
    "LiteralOther": "lo",
    "LiteralString": "s",
    "LiteralStringAffix": "sa",
    "LiteralStringAtom": "lsa",
    "LiteralStringBacktick": "sb",
    "LiteralStringBoolean": "sbo",
    "LiteralStringChar": "sc",
    "LiteralStringDelimiter": "dl",
    "LiteralStringDoc": "sd",
    "LiteralStringDouble": "s2",
    "LiteralStringEscape": "se",
    "LiteralStringHeredoc": "lsh",
    "LiteralStringInterpol": "lsi",
    "LiteralStringName": "lsn",
    "LiteralStringOther": "lso",
    "LiteralStringRegex": "sr",
    "LiteralStringSingle": "s1",
    "LiteralStringSymbol": "ss",
    "Name": "n",
    "NameAttribute": "na",
    "NameBuiltin": "nb",
    "NameBuiltinPseudo": "nbp",
    "NameClass": "nc",
    "NameConstant": "no",
    "NameDecorator": "nd",
    "NameEntity": "ni",
    "NameException": "ne",
    "NameFunction": "nf",
    "NameFunctionMagic": "nfm",
    "NameKeyword": "nk",
    "NameLabel": "nl",
    "NameNamespace": "nn",
    "NameOperator": "op",
    "NameOther": "nx",
    "NameProperty": "py",
    "NameTag": "nt",
    "NameVariable": "nv",
    "NameVariableAnonymous": "nva",
    "NameVariableClass": "nvc",
    "NameVariableGlobal": "nvg",
    "NameVariableInstance": "nvi",
    "NameVariableMagic": "nvm",
    "NamePseudo": "np",
    "None": "n",
    "Operator": "o",
    "OperatorWord": "ow",
    "Other": "x",
    "Punctuation": "p",
    "Text": "t",
    "TextPunctuation": "tp",
    "TextSymbol": "ts",
    "TextWhitespace": "tw",
    "Token": "tok",
    "TokenType": "unt"
  };

  /**
   * Get CSS abbreviation for a token type
   * @param {string} tokenType - The token type
   * @returns {string} The CSS abbreviation
   */
  function getTokenAbbreviation(tokenType) {
    return TokenAbbreviations[tokenType] || "tok";
  }

  /**
   * HTML Formatter - Converts tokens to HTML with syntax highlighting
   */
  class HtmlFormatter {
    constructor(options = {}) {
      this.classPrefix = options.classPrefix || '';
      this.lineNumbers = options.lineNumbers || false;
      this.linkableLineNumbers = options.linkableLineNumbers !== false;
      this.lineNumberStart = options.lineNumberStart || 1;
      this.lineNumberIdPrefix = options.lineNumberIdPrefix || 'line-';
      this.tabWidth = options.tabWidth || 8;
      this.standalone = options.standalone || false;
      this.surroundingPre = options.surroundingPre !== false;
      this.wrapLongLines = options.wrapLongLines || false;
      this.template = options.template || this.getDefaultTemplate();
    }

    /**
     * Format tokens to HTML
     * @param {string} code - The source code
     * @param {Array} tokens - Array of tokens from the lexer
     * @returns {Promise<string>} HTML output
     */
    async format(code, tokens) {
      let output = '';
      let pre = '';
      let post = '';

      // Wrap in standalone HTML if requested
      if (this.standalone) {
        [pre, post] = this.getStandaloneWrappers();
        output += pre;
      }

      // Generate the code body
      output += this.formatTokens(tokens);

      // Close standalone HTML if requested
      if (this.standalone) {
        output += post;
      }

      return output;
    }

    /**
     * Format tokens to HTML (without standalone wrapper)
     * @param {Array} tokens - Array of tokens
     * @returns {string} HTML output
     */
    formatTokens(tokens) {
      let output = '';

      // Opening <pre> and <code>
      if (this.surroundingPre) {
        const preStyle = this.wrapLongLines ? 'style="white-space: pre-wrap; word-break: break-word;"' : '';
        output += `<pre class="${this.getCssClass('Background')}" ${preStyle}>`;
      }
      output += `<code class="${this.getCssClass('Background')}">`;

      let lineNumber = this.lineNumberStart;
      output += this.formatLineNumber(lineNumber, tokens);

      // Format each token
      for (const token of tokens) {
        const escapedValue = this.escapeHtml(token.value);
        output += `<span class="${this.getCssClass(token.type)}">${escapedValue}</span>`;

        // Check if token ends with newline - increment line number and add line label
        if (token.value.endsWith('\n')) {
          lineNumber++;
          output += this.formatLineNumber(lineNumber, tokens);
        }
      }

      // Closing </code> and </pre>
      output += '</code>';
      if (this.surroundingPre) {
        output += '</pre>';
      }

      return output;
    }

    /**
     * Format a line number label
     * @param {number} lineNum - The line number
     * @param {Array} tokens - All tokens (to check if line should be highlighted)
     * @returns {string} HTML for line number
     */
    formatLineNumber(lineNum, tokens) {
      if (!this.lineNumbers) {
        return '';
      }

      const lineLabel = String(lineNum).padStart(4, ' ').padEnd(5, ' ');
      const isHighlighted = this.isHighlighted(lineNum);
      const lineClass = isHighlighted ? `class="${this.getCssClass('LineHighlight')}"` : '';
      const lineId = this.linkableLineNumbers ? `id="${this.lineNumberIdPrefix}${lineNum}"` : '';

      return `<span ${lineId} ${lineClass} style="user-select: none;">${lineLabel} </span>`;
    }

    /**
     * Get CSS class name for a token type
     * @param {string} tokenType - The token type
     * @returns {string} CSS class name
     */
    getCssClass(tokenType) {
      const abbrev = getTokenAbbreviation(tokenType);
      return this.classPrefix + abbrev;
    }

    /**
     * Escape HTML special characters
     * @param {string} text - Text to escape
     * @returns {string} Escaped text
     */
    escapeHtml(text) {
      return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    /**
     * Get standalone HTML wrappers (without CSS - assumes user has CSS)
     * @returns {Array} [preHTML, postHTML]
     */
    getStandaloneWrappers() {
      const template = this.template;

      // Remove {{style_defs}} placeholder since we're not generating CSS
      if (template.includes('{{style_defs}}')) {
        const parts = template.split('{{style_defs}}');
        const bodyParts = parts[1].split('{{body}}');
        return [
          parts[0] + bodyParts[0],
          bodyParts[1] || ''
        ];
      } else {
        const parts = template.split('{{body}}');
        return [parts[0], parts[1] || ''];
      }
    }

    /**
     * Get default HTML template
     * @returns {string} Default template
     */
    getDefaultTemplate() {
      return `<!DOCTYPE html><html><head><style>
{{style_defs}}
</style></head><body>
{{body}}
</body></html>`;
    }

    /**
     * Check if a line should be highlighted
     * @param {number} lineNum - Line number
     * @returns {boolean} True if line should be highlighted
     */
    isHighlighted(lineNum) {
      // TODO: Support highlight_lines option
      return false;
    }
  }

  /**
   * Simple API for syntax highlighting
   * One function to rule them all!
   */


  // Cache for reuse
  const lexerCache = new Map();

  /**
   * Simple syntax highlighting function
   * @param {string} code - The source code to highlight
   * @param {string} language - The lexer/language name (e.g., 'javascript', 'python')
   * @param {object} options - Optional configuration
   * @returns {Promise<string>} HTML string with syntax highlighting
   */
  async function highlight(code, language, options = {}) {
    try {
      // Get or create lexer
      if (!lexerCache.has(language)) {
        const lexerDef = await loadLexer(language);
        const lexer = new Lexer(language);
        await lexer.init();
        lexerCache.set(language, lexer);
      }

      const lexer = lexerCache.get(language);

      // Tokenize the code
      const tokens = await lexer.tokenize(code);

      // Format to HTML
      const formatter = new HtmlFormatter({
        standalone: options.standalone || false,
        lineNumbers: options.lineNumbers || false,
        ...options
      });

      return formatter.format(code, tokens);
    } catch (error) {
      // Return escaped code as fallback
      console.error(`Highlighting error for ${language}:`, error);
      return `<pre><code>${escapeHtml(code)}</code></pre>`;
    }
  }

  /**
   * Escape HTML special characters
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * Web Component: <syntax-highlight>
   * Declarative syntax highlighting for the web
   */


  /**
   * Custom element for syntax highlighting
   * Usage: <syntax-highlight language="javascript" theme="github-dark">code here</syntax-highlight>
   */
  class SyntaxHighlight extends HTMLElement {
    constructor() {
      super();
      this.attachShadow({ mode: 'open' });
    }

    /**
     * Observed attributes - when these change, the component re-renders
     */
    static get observedAttributes() {
      return ['language', 'theme', 'line-numbers', 'standalone'];
    }

    /**
     * Called when element is added to DOM
     */
    connectedCallback() {
      this.render();
    }

    /**
     * Called when observed attributes change
     */
    attributeChangedCallback(name, oldValue, newValue) {
      if (oldValue !== newValue) {
        this.render();
      }
    }

    /**
     * Get the code content from the element
     */
    getCode() {
      // Try to get from <template> first, then from text content
      const template = this.querySelector('template');
      if (template) {
        return template.innerHTML;
      }
      return this.textContent || '';
    }

    /**
     * Render the highlighted code
     */
    async render() {
      const code = this.getCode();
      const language = this.getAttribute('language') || 'plaintext';
      const theme = this.getAttribute('theme') || 'github-dark';
      const lineNumbers = this.hasAttribute('line-numbers');
      const standalone = this.hasAttribute('standalone');

      if (!code.trim()) {
        this.shadowRoot.innerHTML = '';
        return;
      }

      try {
        const html = await highlight(code, language, theme, {
          lineNumbers,
          standalone
        });

        // Add basic styles
        const styles = `
        <style>
          :host {
            display: block;
          }
          pre {
            margin: 0;
            padding: 1rem;
            overflow-x: auto;
          }
          code {
            font-family: 'Fira Code', 'Consolas', 'Monaco', monospace;
            font-size: 0.875rem;
            line-height: 1.6;
          }
        </style>
      `;

        this.shadowRoot.innerHTML = styles + html;

        // Dispatch custom event when done
        this.dispatchEvent(new CustomEvent('highlighted', {
          bubbles: true,
          detail: { language, theme }
        }));
      } catch (error) {
        this.shadowRoot.innerHTML = `
        <style>:host { display: block; }</style>
        <pre style="color: red; padding: 1rem;">Error: ${error.message}</pre>
      `;
      }
    }
  }

  var syntaxHighlight = /*#__PURE__*/Object.freeze({
    __proto__: null,
    default: SyntaxHighlight
  });

  /**
   * Browser exports for tartrazine.js
   * This is the main entry point for browser usage
   */


  // Auto-register web component
  if (typeof window !== 'undefined' && !customElements.get('syntax-highlight')) {
    Promise.resolve().then(function () { return syntaxHighlight; }).then(module => {
      customElements.define('syntax-highlight', module.default);
    });
  }

  exports.HtmlFormatter = HtmlFormatter;
  exports.Lexer = Lexer;
  exports.SyntaxHighlight = SyntaxHighlight;
  exports.getTokenAbbreviation = getTokenAbbreviation;
  exports.highlight = highlight;
  exports.loadLexer = loadLexer;

  return exports;

})({});
//# sourceMappingURL=tartrazine.iife.js.map
