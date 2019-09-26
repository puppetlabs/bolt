/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2010 IBM Corporation
 *
 * See the accompanying LICENSE file for applicable license.
 */
package org.dita.dost.ant;

import static org.dita.dost.util.Constants.*;
import static org.apache.commons.io.FileUtils.*;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.Map.Entry;

import javax.xml.parsers.DocumentBuilder;

import org.apache.tools.ant.Project;
import org.apache.tools.ant.Task;
import org.dita.dost.log.DITAOTLogger;
import org.dita.dost.log.DITAOTAntLogger;
import org.dita.dost.util.FileUtils;
import org.dita.dost.util.XMLUtils;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * This class is for converting charset and escaping
 * entities in html help component files.
 *
 * @version 1.0 2010-09-30
 *
 * @author Zhang Di Hua
 */
public final class ConvertLang extends Task {

    private static final String ATTRIBUTE_FORMAT_VALUE_WINDOWS = "windows";
    private static final String ATTRIBUTE_FORMAT_VALUE_HTML = "html";

    private static final String tag1 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
    private static final String tag2 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>[OPTIONS]";
    private static final String tag3 = "&lt;?xml version=\"1.0\" encoding=\"utf-8\"?&gt;";

    private static final String CODEPAGE_ISO_8859_1 = "iso-8859-1";
    private static final String CODEPAGE_ISO_8859_2 = "iso-8859-2";
    private static final String CODEPAGE_ISO_8859_7 = "iso-8859-7";
    private static final String CODEPAGE_1250 = "windows-1250";
    private static final String CODEPAGE_1252 = "windows-1252";
    private static final String CODEPAGE_1253 = "windows-1253";

    private String basedir;

    private String outputdir;

    private String message;

    private String langcode;
    //charset map(e.g html = iso-8859-1)
    private final Map<String, String>charsetMap = new HashMap<>();
    //lang map(e.g ar- = 0x0c01 Arabic (EGYPT))
    private final Map<String, String>langMap = new HashMap<>();
    //entity map(e.g 38 = &amp;)
    private final Map<String, String>entityMap = new HashMap<>();
    //Exceptions that should not generate entities
    private Set<Integer> entityExceptionSet;
    //Charset currently stored in exception list
    private String exceptionCharset;


    private DITAOTLogger logger;

    /**
     * Executes the Ant task.
     */
    @Override
    public void execute() {
        logger = new DITAOTAntLogger(getProject());
        logger.info(message);

        //ensure outdir is absolute
        if (!new File(outputdir).isAbsolute()) {
            outputdir = new File(basedir, outputdir).getAbsolutePath();
        }

        //initialize language map
        createLangMap();
        //initialize entity map
        createEntityMap();
        //Initialize entitye exceptions
        entityExceptionSet = new HashSet<>(128);
        //initialize charset map
        createCharsetMap();
        //change charset of html files
        convertHtmlCharset();
        //update entity and lang code
        updateAllEntitiesAndLangs();
    }

    private void createLangMap() {

        final Properties entities = new Properties();
        InputStream in = null;
        try {
            in = getClass().getClassLoader().getResourceAsStream("org/dita/dost/util/languages.properties");
            entities.load(in);
        } catch (final IOException e) {
            throw new RuntimeException("Failed to read language property file: " + e.getMessage(), e);
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (final IOException e) {}
            }
        }
        for (final Entry<Object, Object> e: entities.entrySet()) {
            langMap.put((String) e.getKey(), (String) e.getValue());
        }

    }

    private void createEntityMap() {

        final Properties entities = new Properties();
        InputStream in = null;
        try {
            in = getClass().getClassLoader().getResourceAsStream("org/dita/dost/util/entities.properties");
            entities.load(in);
        } catch (final IOException e) {
            throw new RuntimeException("Failed to read entities property file: " + e.getMessage(), e);
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (final IOException e) {}
            }
        }
        for (final Entry<Object, Object> e: entities.entrySet()) {
            entityMap.put((String) e.getKey(), (String) e.getValue());
        }

    }

    private void createCharsetMap() {
        InputStream in = null;
        try {
            in = getClass().getClassLoader().getResourceAsStream("org/dita/dost/util/codepages.xml");
            final DocumentBuilder builder = XMLUtils.getDocumentBuilder();
            final Document doc = builder.parse(in);
            final Element root = doc.getDocumentElement();
            final NodeList childNodes = root.getChildNodes();
            //search the node with langcode
            for (int i = 0; i < childNodes.getLength(); i++) {
                final Node node = childNodes.item(i);
                //only for element node
                if (node.getNodeType() == Node.ELEMENT_NODE) {
                    final Element e = (Element)node;
                    final String lang = e.getAttribute(ATTRIBUTE_NAME_LANG);
                    //node found
                    if (langcode.equalsIgnoreCase(lang)||
                            lang.startsWith(langcode)) {
                        //store the value into a map
                        //charsetMap = new HashMap<String, String>();
                        //iterate child nodes skip the 1st one
                        final NodeList subChild = e.getChildNodes();
                        for (int j = 0; j < subChild.getLength(); j++) {
                            final Node subNode = subChild.item(j);
                            if (subNode.getNodeType() == Node.ELEMENT_NODE) {
                                final Element elem = (Element)subNode;
                                final String format = elem.getAttribute(ATTRIBUTE_NAME_FORMAT);
                                final String charset = elem.getAttribute(ATTRIBUTE_NAME_CHARSET);
                                //store charset into map
                                charsetMap.put(format, charset);
                            }

                        }
                        break;
                    }
                }
            }
            //no matched charset is found set default value en-us
            if (charsetMap.size() == 0) {
                charsetMap.put(ATTRIBUTE_FORMAT_VALUE_HTML, "iso-8859-1");
                charsetMap.put(ATTRIBUTE_FORMAT_VALUE_WINDOWS, "windows-1252");
            }
        } catch (final Exception e) {
            throw new RuntimeException("Failed to read charset configuration file: " + e.getMessage(), e);
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (final IOException e) {}
            }
        }
    }

    private String replaceXmlTag(final String source, final String tag) {
        final int startPos = source.indexOf(tag);
        final int endPos = startPos + tag.length();
        return source.substring(0, startPos) + source.substring(endPos);
    }

    private void convertHtmlCharset() {
        final File outputDir = new File(outputdir);
        final File[] files = outputDir.listFiles();
        if (files != null) {
            for (final File file : files) {
                //Recursive method
                convertCharset(file);
            }
        }
    }
    //Recursive method
    private void convertCharset(final File inputFile) {
        if (inputFile.isDirectory()) {
            final File[] files = inputFile.listFiles();
            if (files != null) {
                for (final File file : files) {
                    convertCharset(file);
                }
            }
        } else if (FileUtils.isHTMLFile(inputFile.getName())||
                FileUtils.isHHCFile(inputFile.getName())||
                FileUtils.isHHKFile(inputFile.getName())) {

            final String fileName = inputFile.getAbsolutePath();
            final File outputFile = new File(fileName + FILE_EXTENSION_TEMP);
            log("Processing " + fileName, Project.MSG_INFO);
            BufferedReader reader = null;
            Writer writer = null;
            try {
                //prepare for the input and output
                final FileInputStream inputStream = new FileInputStream(inputFile);
                final InputStreamReader streamReader = new InputStreamReader(inputStream, UTF8);
                reader = new BufferedReader(streamReader);

                final FileOutputStream outputStream = new FileOutputStream(outputFile);
                final OutputStreamWriter streamWriter = new OutputStreamWriter(outputStream, UTF8);
                writer = new BufferedWriter(streamWriter);

                String value = reader.readLine();
                while(value != null) {
                    //meta tag contains charset found
                    if (value.contains("<meta http-equiv") && value.contains("charset")) {
                        final int insertPoint = value.indexOf("charset=") + "charset=".length();
                        final String subString = value.substring(0, insertPoint);
                        final int remainIndex = value.indexOf(UTF8) + UTF8.length();
                        final String remainString = value.substring(remainIndex);
                        //change the charset
                        final String newValue = (FileUtils.isHHCFile(inputFile.getName()) || FileUtils.isHHKFile(inputFile.getName()) ?
                                                 subString + charsetMap.get(ATTRIBUTE_FORMAT_VALUE_WINDOWS) + remainString :
                                                 subString + charsetMap.get(ATTRIBUTE_FORMAT_VALUE_HTML) + remainString);
                        //write into the output file
                        writer.write(newValue);
                        //add line break
                        writer.write(LINE_SEPARATOR);
                    } else {
                        if (value.contains(tag1)) {
                            value = replaceXmlTag(value, tag1);
                        } else if (value.contains(tag2)) {
                            value = replaceXmlTag(value, tag2);
                        } else if (value.contains(tag3)) {
                            value = replaceXmlTag(value, tag3);
                        }

                        //other values
                        writer.write(value);
                        writer.write(LINE_SEPARATOR);
                    }
                    value = reader.readLine();
                }
            } catch (final FileNotFoundException e) {
                logger.error(e.getMessage(), e) ;
            } catch (final UnsupportedEncodingException e) {
                throw new RuntimeException(e);
            } catch (final IOException e) {
                logger.error(e.getMessage(), e) ;
            } finally {
                if (reader != null) {
                    try {
                        reader.close();
                    } catch (final IOException e) {
                        logger.error("Failed to close input stream: " + e.getMessage());
                    }
                }
                if (writer != null) {
                    try {
                        writer.close();
                    } catch (final IOException e) {
                        logger.error("Failed to close output stream: " + e.getMessage());
                    }
                }
            }
            try {
                deleteQuietly(inputFile);
                moveFile(outputFile, inputFile);
            } catch (final Exception e) {
                logger.error("Failed to replace " + inputFile + ": " + e.getMessage());
            }
        }
    }

    private void updateAllEntitiesAndLangs() {
        final File outputDir = new File(outputdir);
        final File[] files = outputDir.listFiles();
        if (files != null) {
            for (final File file : files) {
                //Recursive method
                updateEntityAndLang(file);
            }
        }
    }
    //Recursive method
    private void updateEntityAndLang(final File inputFile) {
        //directory case
        if (inputFile.isDirectory()) {
            final File[] files = inputFile.listFiles();
            if (files != null) {
                for (final File file : files) {
                    updateEntityAndLang(file);
                }
            }
        }
        //html file case
        else if (FileUtils.isHTMLFile(inputFile.getName())) {
            //do converting work
            convertEntityAndCharset(inputFile, ATTRIBUTE_FORMAT_VALUE_HTML);

        }
        //hhp/hhc/hhk file case
        else if (FileUtils.isHHPFile(inputFile.getName()) ||
                FileUtils.isHHCFile(inputFile.getName()) ||
                FileUtils.isHHKFile(inputFile.getName())) {
            //do converting work
            convertEntityAndCharset(inputFile, ATTRIBUTE_FORMAT_VALUE_WINDOWS);
            //update language setting of hhp file
            final String fileName = inputFile.getAbsolutePath();
            final File outputFile = new File(fileName + FILE_EXTENSION_TEMP);
            //get new charset
            final String charset = charsetMap.get(ATTRIBUTE_FORMAT_VALUE_WINDOWS);
            BufferedReader reader = null;
            BufferedWriter writer = null;
            try {
                //prepare for the input and output
                final FileInputStream inputStream = new FileInputStream(inputFile);
                final InputStreamReader streamReader = new InputStreamReader(inputStream, charset);
                //wrapped into reader
                reader = new BufferedReader(streamReader);

                final FileOutputStream outputStream = new FileOutputStream(outputFile);

                //convert charset
                final OutputStreamWriter streamWriter = new OutputStreamWriter(outputStream, charset);
                //wrapped into writer
                writer = new BufferedWriter(streamWriter);

                String value = reader.readLine();
                while(value != null) {
                    if (value.contains(tag1)) {
                        value = replaceXmlTag(value, tag1);
                    } else if (value.contains(tag2)) {
                        value = replaceXmlTag(value, tag2);
                    } else if (value.contains(tag3)) {
                        value = replaceXmlTag(value, tag3);
                    }

                    //meta tag contains charset found
                    if (value.contains("Language=")) {
                        String newValue = langMap.get(langcode);
                        if (newValue == null) {
                            newValue = langMap.get(langcode.split("-")[0]);
                        }
                        if (newValue != null) {
                            writer.write("Language=" + newValue);
                            writer.write(LINE_SEPARATOR);
                        } else {
                            throw new IllegalArgumentException("Unsupported language code '" + langcode + "', unable to map to a Locale ID.");
                        }

                    } else {
                        //other values
                        writer.write(value);
                        writer.write(LINE_SEPARATOR);
                    }
                    value = reader.readLine();
                }
            } catch (final FileNotFoundException e) {
                logger.error(e.getMessage(), e) ;
            } catch (final UnsupportedEncodingException e) {
                throw new RuntimeException(e);
            } catch (final IOException e) {
                logger.error(e.getMessage(), e) ;
            } finally {
                if (reader != null) {
                    try {
                        reader.close();
                    } catch (final IOException e) {
                        logger.error("Failed to close input stream: " + e.getMessage());
                    }
                }
                if (writer != null) {
                    try {
                        writer.close();
                    } catch (final IOException e) {
                        logger.error("Failed to close output stream: " + e.getMessage());
                    }
                }
            }
            try {
                deleteQuietly(inputFile);
                moveFile(outputFile, inputFile);
            } catch (final Exception e) {
                logger.error("Failed to replace " + inputFile + ": " + e.getMessage());
            }
        }

    }

    private void updateExceptionCharacters(final String charset) {
        if (exceptionCharset != null && exceptionCharset.equals(charset)) {
            return;
        }
        exceptionCharset = charset;
        if (!entityExceptionSet.isEmpty()) {
            entityExceptionSet.clear();
        }
        if (charset.equals(CODEPAGE_ISO_8859_2) || charset.equals(CODEPAGE_1250) ||
                charset.equals(CODEPAGE_ISO_8859_1) || charset.equals(CODEPAGE_1252)) {
            entityExceptionSet.add(193); entityExceptionSet.add(225);//A-acute
            entityExceptionSet.add(194); entityExceptionSet.add(226);//A-circumflex
            entityExceptionSet.add(196); entityExceptionSet.add(228);//A-umlaut
            entityExceptionSet.add(199); entityExceptionSet.add(231);//C-cedilla
            entityExceptionSet.add(201); entityExceptionSet.add(233);//E-acute
            entityExceptionSet.add(203); entityExceptionSet.add(235);//E-umlaut
            entityExceptionSet.add(205); entityExceptionSet.add(237);//I-acute
            entityExceptionSet.add(206); entityExceptionSet.add(238);//I-circumflex
            entityExceptionSet.add(211); entityExceptionSet.add(243);//O-acute
            entityExceptionSet.add(212); entityExceptionSet.add(244);//O-circumflex
            entityExceptionSet.add(214); entityExceptionSet.add(246);//O-umlaut
            entityExceptionSet.add(218); entityExceptionSet.add(250);//U-acute
            entityExceptionSet.add(220); entityExceptionSet.add(252);//U-umlaut
            entityExceptionSet.add(221); entityExceptionSet.add(253);//Y-acute
            entityExceptionSet.add(223); //Szlig
            entityExceptionSet.add(215); //&times;
        }
        if (charset.equals(CODEPAGE_ISO_8859_1) || charset.equals(CODEPAGE_1252)) {
            entityExceptionSet.add(192); entityExceptionSet.add(224);//A-grave
            entityExceptionSet.add(195); entityExceptionSet.add(227);//A-tilde
            entityExceptionSet.add(197); entityExceptionSet.add(229);//A-ring
            entityExceptionSet.add(198); entityExceptionSet.add(230);//AElig
            entityExceptionSet.add(200); entityExceptionSet.add(232);//E-grave
            entityExceptionSet.add(202); entityExceptionSet.add(234);//E-circumflex
            entityExceptionSet.add(204); entityExceptionSet.add(236);//I-grave
            entityExceptionSet.add(207); entityExceptionSet.add(239);//I-uml
            entityExceptionSet.add(208); entityExceptionSet.add(240);//ETH
            entityExceptionSet.add(209); entityExceptionSet.add(241);//N-tilde
            entityExceptionSet.add(210); entityExceptionSet.add(242);//O-grave
            entityExceptionSet.add(213); entityExceptionSet.add(245);//O-tilde
            entityExceptionSet.add(216); entityExceptionSet.add(248);//O-slash
            entityExceptionSet.add(217); entityExceptionSet.add(249);//U-grave
            entityExceptionSet.add(219); entityExceptionSet.add(251);//O-circumflex
            entityExceptionSet.add(222); entityExceptionSet.add(254);//Thorn
            entityExceptionSet.add(255);//y-umlaut
        } else if (charset.equals(CODEPAGE_ISO_8859_2) || charset.equals(CODEPAGE_1250)) {
            entityExceptionSet.add(352); entityExceptionSet.add(353);//S-caron
        } else if (charset.equals(CODEPAGE_ISO_8859_7) || charset.equals(CODEPAGE_1253)) {
            entityExceptionSet.add(913); entityExceptionSet.add(945);//Alpha
            entityExceptionSet.add(914); entityExceptionSet.add(946);
            entityExceptionSet.add(915); entityExceptionSet.add(947);
            entityExceptionSet.add(916); entityExceptionSet.add(948);
            entityExceptionSet.add(917); entityExceptionSet.add(949);
            entityExceptionSet.add(918); entityExceptionSet.add(950);
            entityExceptionSet.add(919); entityExceptionSet.add(951);
            entityExceptionSet.add(920); entityExceptionSet.add(952);
            entityExceptionSet.add(921); entityExceptionSet.add(953);
            entityExceptionSet.add(922); entityExceptionSet.add(954);
            entityExceptionSet.add(923); entityExceptionSet.add(955);
            entityExceptionSet.add(924); entityExceptionSet.add(956);
            entityExceptionSet.add(925); entityExceptionSet.add(957);
            entityExceptionSet.add(926); entityExceptionSet.add(958);
            entityExceptionSet.add(927); entityExceptionSet.add(959);
            entityExceptionSet.add(928); entityExceptionSet.add(960);
            entityExceptionSet.add(929); entityExceptionSet.add(961);
            entityExceptionSet.add(930); entityExceptionSet.add(962);
            entityExceptionSet.add(931); entityExceptionSet.add(963);
            entityExceptionSet.add(932); entityExceptionSet.add(964);
            entityExceptionSet.add(933); entityExceptionSet.add(965);
            entityExceptionSet.add(934); entityExceptionSet.add(966);
            entityExceptionSet.add(935); entityExceptionSet.add(967);
            entityExceptionSet.add(936); entityExceptionSet.add(968);
            entityExceptionSet.add(937); entityExceptionSet.add(969);//Omega
        }
    }

    private void convertEntityAndCharset(final File inputFile, final String format) {
        final String fileName = inputFile.getAbsolutePath();
        final File outputFile = new File(fileName + FILE_EXTENSION_TEMP);
        BufferedReader reader = null;
        BufferedWriter writer = null;
        try {
            //prepare for the input and output
            final FileInputStream inputStream = new FileInputStream(inputFile);
            final InputStreamReader streamReader = new InputStreamReader(inputStream, UTF8);
            //wrapped into reader
            reader = new BufferedReader(streamReader);

            final FileOutputStream outputStream = new FileOutputStream(outputFile);
            //get new charset
            final String charset = charsetMap.get(format);
            //convert charset
            final OutputStreamWriter streamWriter = new OutputStreamWriter(outputStream, charset);
            //wrapped into writer
            writer = new BufferedWriter(streamWriter);
            updateExceptionCharacters(charset);

            //read a character
            int charCode = reader.read();
            while(charCode != -1) {
                final String key = String.valueOf(charCode);
                //Is an entity char
                if (entityMap.containsKey(key) &&
                        !entityExceptionSet.contains(charCode)) {
                    //get related entity
                    final String value = entityMap.get(key);
                    //write entity into output file
                    writer.write(value);
                } else {
                    //normal process
                    writer.write(charCode);
                }
                charCode = reader.read();
            }
        } catch (final IOException e) {
            logger.error(e.getMessage(), e) ;
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (final IOException e) {
                    logger.error("Failed to close input stream: " + e.getMessage());
                }
            }
            if (writer != null) {
                try {
                    writer.close();
                } catch (final IOException e) {
                    logger.error("Failed to close output stream: " + e.getMessage());
                }
            }
        }
        try {
            deleteQuietly(inputFile);
            moveFile(outputFile, inputFile);
        } catch (final Exception e) {
            logger.error("Failed to replace " + inputFile + ": " + e.getMessage());
        }
    }

    public void setBasedir(final String basedir) {
        this.basedir = basedir;
    }

    public void setLangcode(final String langcode) {
        this.langcode = langcode;
    }

    public void setMessage(final String message) {
        this.message = message;
    }

    public void setOutputdir(final String outputdir) {
        this.outputdir = outputdir;
    }

}
