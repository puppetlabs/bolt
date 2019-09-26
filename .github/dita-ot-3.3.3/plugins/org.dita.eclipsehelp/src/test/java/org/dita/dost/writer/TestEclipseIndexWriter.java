/*
 * This file is part of the DITA Open Toolkit project.
 * See the accompanying LICENSE file for applicable license.
 */
/*
 * Copyright 2010 IBM Corporation
 */
package org.dita.dost.writer;

import static org.dita.dost.TestUtils.assertXMLEqual;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.dita.dost.TestUtils;
import org.dita.dost.exception.DITAOTException;
import org.dita.dost.index.IndexTerm;

public class TestEclipseIndexWriter {

    private static File tempDir;
    private static final File resourceDir = TestUtils.getResourceDir(TestEclipseIndexWriter.class);
    private static final File expDir = new File(resourceDir, "exp");

    @BeforeClass
    public static void setUp() throws IOException {
        tempDir = TestUtils.createTempDir(TestEclipseIndexWriter.class);
    }

    @Test
    public void testwrite() throws DITAOTException, SAXException, IOException {
//        final Content content = new ContentImpl();
        final IndexTerm indexterm1 = new IndexTerm();
        indexterm1.setTermName("name1");
        indexterm1.setTermKey("indexkey1");
        final IndexTerm indexterm2 = new IndexTerm();
        indexterm2.setTermName("name2");
        indexterm2.setTermKey("indexkey2");
        indexterm1.addSubTerm(indexterm2);
        final List<IndexTerm> collection = new ArrayList<IndexTerm>();
        collection.add(indexterm1);
//        content.setCollection(collection);

        final EclipseIndexWriter indexWriter = new EclipseIndexWriter();
//        indexWriter.setContent(content);
        indexWriter.setTermList(collection);
        final File outFile = new File(tempDir, "index.xml");
        indexWriter.write(outFile.getAbsoluteFile());

        assertXMLEqual(new InputSource(new File(expDir, "index.xml").toURI().toString()),
                new InputSource(outFile.toURI().toString()));
    }

    @AfterClass
    public static void tearDown() throws IOException {
        TestUtils.forceDelete(tempDir);
    }

}
